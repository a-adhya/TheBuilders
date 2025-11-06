from dataclasses_json import dataclass_json, config
import json
import re
from sse_starlette.sse import EventSourceResponse
from http.client import HTTPException
import httpx
from starlette.background import BackgroundTask
from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse, Response, StreamingResponse
from typing import List, Optional
from dataclasses import dataclass, field
from http import HTTPStatus
import main
import toolbox
from toolbox import getWeather, toolInvoke, TOOLBOX, OllamaToolCall, OllamaToolSchema

OLLAMA_BASE_URL = "http://localhost:11434/api"
asyncClient = httpx.AsyncClient(timeout=None, http2=True)

async def llmprompt(request):
    # https://www.python-httpx.org/async/
    response = await asyncClient.send(
        asyncClient.build_request(
            method=request.method,
            url=f"{OLLAMA_BASE_URL}/generate",
            data=await request.body()
        ), stream=True)

    if response.status_code != 200:
        return Response(headers=response.headers, content=await response.aread())

    return StreamingResponse(response.aiter_raw(),
                             media_type="application/x-ndjson",
                             background=BackgroundTask(response.aclose))


@dataclass_json
@dataclass
class OllamaMessage:
    role: str
    content: str
    toolCalls: Optional[List[toolbox.OllamaToolCall]] = field(
        default=None,
        metadata=config(field_name="tool_calls", exclude=lambda l: not l)  # exclude if empty (None, [])
    )

    @staticmethod
    def fromRow(row, ollamaRequest):
        try:
            toolcalls = []
            if row[2]:
                # must deserialize to type to append toolcalls
                toolcalls = [OllamaToolCall.from_dict(tool_call) for tool_call in json.loads(row[2])]

            ollamaRequest.messages.append(
                OllamaMessage(role=row[0], content=row[1], toolCalls=toolcalls))

            if row[3]:
                # has device tools
                # must deserialize to type and append device tools to ollamaRequest.tools
                ollamaRequest.tools.extend([OllamaToolSchema.from_dict(tool) for tool in json.loads(row[3])])
        except Exception as err:
            raise err


@dataclass_json
@dataclass
class OllamaRequest:
    appID: str
    model: str
    messages: List[OllamaMessage]
    stream: bool
    tools: Optional[List[toolbox.OllamaToolSchema]] = field(
        default=None,
        metadata=config(exclude=lambda l: not l)
    )


@dataclass_json
@dataclass
class OllamaResponse:
    model: str
    created_at: str
    message: OllamaMessage


@dataclass
class Location:
    lat: str
    lon: str


async def weather(request):
    try:
        loc = Location(**(await request.json()))
    except Exception as err:
        print(f'{err=}')
        return JSONResponse(f'Unprocessable entity: {str(err)}',
                            status_code=HTTPStatus.UNPROCESSABLE_ENTITY)

    temp, err = await toolbox.getWeather([loc.lat, loc.lon])
    if err:
        return JSONResponse({"error": f'Internal server error: {str(err)}'},
                            status_code=HTTPStatus.INTERNAL_SERVER_ERROR)
    return JSONResponse(temp)


async def llmtools(request):
    try:
        ollamaRequest = OllamaRequest.from_json(await request.body(), infer_missing=True)
    except Exception as err:
        return JSONResponse({"error": f'Deserializing request: {type(err).__name__}: {str(err)}'},
                            status_code=HTTPStatus.UNPROCESSABLE_ENTITY)

    if ollamaRequest.appID == "":
        return JSONResponse(f'Invalid appID: {ollamaRequest.appID}',
                            status_code=HTTPStatus.UNPROCESSABLE_ENTITY)

    try:
        # convert tools from client as JSON string (client_tools) and save to db;
        # prepare ollama_request for re-use to be sent to Ollama:
        # clear tools in request, to be populated later
        client_tools = []
        if (ollamaRequest.tools):
            try:
                # has device tools
                # must marshal to string to store to db
                client_tools = json.dumps([tool.to_dict() for tool in ollamaRequest.tools])

                # reset tools, to be populated with
                # accumulated tools below, without duplicates
                ollamaRequest.tools = None
            except Exception as err:
                return JSONResponse({"error": f'Serializing request tools: {type(err).__name__}: {str(err)}'},
                                    status_code=HTTPStatus.UNPROCESSABLE_ENTITY)

        if ollamaRequest.messages:
            async with main.server.pool.connection() as conn:
                async with conn.cursor() as cur:
                    # insert each message into the database
                    # insert client_tools only with the first message:
                    # reset it to empty after first message.
                    for msg in ollamaRequest.messages:
                        try:
                            await cur.execute(
                                'INSERT INTO chatts (username, message, id, appid, toolschemas) VALUES (%s, %s, gen_random_uuid(), %s, %s);',
                                (msg.role, msg.content, ollamaRequest.appID, client_tools))
                        except Exception as err:
                            return JSONResponse({"error": f'Inserting tools: {type(err).__name__}: {str(err)}'},
                                                status_code=HTTPStatus.INTERNAL_SERVER_ERROR)

                        # store device's tools only once
                        client_tools = None

    except Exception as err:
        return JSONResponse({"error": f'Processing request: {type(err).__name__}: {str(err)}'},
                            status_code=HTTPStatus.INTERNAL_SERVER_ERROR)

    # append all of chatterd's resident tools to ollamaRequest
    ollamaRequest.tools = []
    for tool in TOOLBOX.values():
        ollamaRequest.tools.append(tool.schema)

    try:
        # reconstruct ollamaRequest to be sent to Ollama:
        # - add context: retrieve all past messages by appID,
        #   incl. the one just received, and attach them to
        #   ollamaRequest
        # - convert each back to OllamaMessage and
        # - insert it into ollamaRequest
        # - add each message's clientTools to chatterd's resident tools
        #   already copied to ollamaRequest.tools.
        ollamaRequest.messages = []
        async with main.server.pool.connection() as conn:
            async with conn.cursor() as cur:
                await cur.execute('SELECT username, message, toolcalls, toolschemas FROM chatts WHERE appID = %s ORDER BY time ASC;',
                                  (ollamaRequest.appID,))
                rows = await cur.fetchall()
                for row in rows:
                    OllamaMessage.fromRow(row, ollamaRequest)
    except Exception as err:
        return JSONResponse({"error": f'{type(err).__name__}: {str(err)}'},
                            status_code=HTTPStatus.INTERNAL_SERVER_ERROR)

    async def ndjson_yield_sse():
        full_response = ""
        sendNewPrompt = True

        while (sendNewPrompt):
            sendNewPrompt = False  # assume no resident-tool call

            try:
                # Send request to Ollama
                async with client.stream(
                        method=request.method,
                        url=f"{OLLAMA_BASE_URL}/chat",
                        content=ollamaRequest.to_json().encode("utf-8"),  # convert the request to JSON
                ) as response:

                    tool_calls = ""
                    tool_result = ""

                    async for line in response.aiter_lines():
                        try:
                            if line:
                                # deserialize each line into OllamaResponse
                                ollamaResponse = OllamaResponse.from_json(line)

                                if not ollamaResponse.model:
                                    # didn't receive an ollamaresponse, report to client as error
                                    yield {
                                        "event": "error",
                                        "data": line.replace("\\\"", "'")
                                    }

                                # append response token to full assistant message
                                full_response += ollamaResponse.message.content

                                # is there a tool call?
                                if ollamaResponse.message.toolCalls:
                                    # convert toolCalls to JSON string (tool_calls) to be saved to db
                                    tool_calls = json.dumps(
                                        [toolCall.to_dict() for toolCall in ollamaResponse.message.toolCalls])

                                    for toolCall in ollamaResponse.message.toolCalls:
                                        if not toolCall.function.name:
                                            continue  # LLM miscalled

                                        toolResult, err = await toolInvoke(toolCall.function)

                                        if toolResult:
                                            # outcome 2: tool call is resident and no error

                                            # convert toolResult to JSON string (tool_result)
                                            # to be saved to db
                                            tool_result += toolResult if not tool_result else f' {toolResult}'

                                            # create new OllamaMessage with tool result
                                            # to be sent back to Ollama
                                            toolresultMsg = OllamaMessage(
                                                role="tool",
                                                content=toolResult,
                                            )
                                            ollamaRequest.messages.append(toolresultMsg)

                                            # send result back to Ollama
                                            sendNewPrompt = True
                                        elif err:
                                            # outcome 1: tool resident but had error
                                            yield {
                                                "event": "error",
                                                "data": f'error'
                                            }
                                        else:
                                            # outcome 3: tool non resident, forward
                                            # to device as 'tool_calls' SSE event
                                            yield {
                                                "event": "tool_calls",
                                                "data": line
                                            }
                                else:
                                    # no tool call, send NDJSON line as SSE data line
                                    yield {
                                        "data": line
                                    }

                        except Exception as err:
                            yield {
                                "event": "error",
                                "data": f'error'
                            }

                    async with main.server.pool.connection() as conn:
                        async with conn.cursor() as cur:
                            # save full response, including tool call(s), to db,
                            # to form part of next prompt's history
                            await cur.execute(
                                'INSERT INTO chatts (username, message, id, appID, toolcalls) \
                                VALUES (%s, %s, gen_random_uuid(), %s, %s);',
                                ("assistant", re.sub(r"\s+", " ", full_response),
                                 ollamaRequest.appID, tool_calls)
                            )

                            # if there were resident tool call(s), save result(s)
                            if sendNewPrompt:
                                await cur.execute(
                                    'INSERT INTO chatts (username, message, id, appid)\
                                     VALUES (%s, %s, gen_random_uuid(), %s);',
                                    ('tool', tool_result, ollamaRequest.appID))

            except Exception as err:
                yield {
                    "event": "error",
                    "data": f'error'
                }

    return EventSourceResponse(ndjson_yield_sse())
