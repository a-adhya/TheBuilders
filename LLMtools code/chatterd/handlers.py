from http.client import HTTPException
import httpx
from starlette.background import BackgroundTask
from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse, Response, StreamingResponse
from dataclasses_json import dataclass_json, config
import json
import re
from sse_starlette.sse import EventSourceResponse
from dataclasses import dataclass, field
from http import HTTPStatus
import main
import toolbox
from toolbox import getWeather, toolInvoke, TOOLBOX, OllamaToolCall, OllamaToolSchema
from typing import List, Optional

OLLAMA_BASE_URL = "http://localhost:11434/api"
asyncClient = httpx.AsyncClient(timeout=None, http2=True)

async def llmprompt(request):
    # https://www.python-httpx.org/async/
    response = await asyncClient.send(
        asyncClient.build_request(
            method = request.method,
            url = f"{OLLAMA_BASE_URL}/generate",
            data=await request.body()
        ), stream = True)

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
        metadata=config(field_name="tool_calls", exclude=lambda l: not l)
    )

    @staticmethod
    def fromRow(row, ollamaRequest):
        try:
            toolcalls = []
            if row[2]:
                toolcalls = [OllamaToolCall.from_dict(tc) for tc in json.loads(row[2])]
            ollamaRequest.messages.append(
                OllamaMessage(role=row[0], content=row[1], toolCalls=toolcalls)
            )
            if row[3]:
                ollamaRequest.tools.extend(
                    [OllamaToolSchema.from_dict(t) for t in json.loads(row[3])]
                )
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

from starlette.responses import JSONResponse

async def weather(request):
    try:
        loc = Location(**(await request.json()))
    except Exception as err:
        return JSONResponse(f'Unprocessable entity: {str(err)}',
                            status_code=HTTPStatus.UNPROCESSABLE_ENTITY)
    temp, err = await toolbox.getWeather([loc.lat, loc.lon])
    if err:
        return JSONResponse({"error": f'Internal server error: {str(err)}'},
                            status_code=HTTPStatus.INTERNAL_SERVER_ERROR)
    return JSONResponse(temp)

from starlette.requests import Request

OLLAMA_BASE_URL = "http://localhost:11434"  # adjust if different

async def llmtools(request: Request):
    # Parse request
    try:
        ollamaRequest = OllamaRequest.from_json(await request.body(), infer_missing=True)
    except Exception as err:
        return JSONResponse({"error": f'Deserializing request: {type(err).__name__}: {str(err)}'},
                            status_code=HTTPStatus.UNPROCESSABLE_ENTITY)
    if ollamaRequest.appID == "":
        return JSONResponse(f'Invalid appID: {ollamaRequest.appID}',
                            status_code=HTTPStatus.UNPROCESSABLE_ENTITY)

    # Capture client tools (if any), persist with first message
    try:
        client_tools = []
        if ollamaRequest.tools:
            try:
                client_tools = json.dumps([t.to_dict() for t in ollamaRequest.tools])
                ollamaRequest.tools = None
            except Exception as err:
                return JSONResponse({"error": f'Serializing request tools: {type(err).__name__}: {str(err)}'},
                                    status_code=HTTPStatus.UNPROCESSABLE_ENTITY)

        if ollamaRequest.messages:
            async with main.server.pool.connection() as conn:
                async with conn.cursor() as cur:
                    for msg in ollamaRequest.messages:
                        try:
                            await cur.execute(
                                'INSERT INTO chatts (username, message, id, appid, toolschemas) '
                                'VALUES (%s, %s, gen_random_uuid(), %s, %s);',
                                (msg.role, msg.content, ollamaRequest.appID, client_tools))
                        except Exception as err:
                            return JSONResponse({"error": f'Inserting tools: {type(err).__name__}: {str(err)}'},
                                                status_code=HTTPStatus.INTERNAL_SERVER_ERROR)
                        client_tools = None  # only once
    except Exception as err:
        return JSONResponse({"error": f'Processing request: {type(err).__name__}: {str(err)}'},
                            status_code=HTTPStatus.INTERNAL_SERVER_ERROR)

    # Assemble resident tools
    ollamaRequest.tools = []
    for tool in TOOLBOX.values():
        ollamaRequest.tools.append(tool.schema)

    # Rebuild request with full history and accumulated tools
    try:
        ollamaRequest.messages = []
        async with main.server.pool.connection() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    'SELECT username, message, toolcalls, toolschemas '
                    'FROM chatts WHERE appID = %s ORDER BY time ASC;',
                    (ollamaRequest.appID,))
                rows = await cur.fetchall()
                for row in rows:
                    OllamaMessage.fromRow(row, ollamaRequest)
    except Exception as err:
        return JSONResponse({"error": f'{type(err).__name__}: {str(err)}'},
                            status_code=HTTPStatus.INTERNAL_SERVER_ERROR)

    # Stream NDJSON from Ollama → SSE to client; handle tool calls
    async def ndjson_yield_sse():
        import httpx
        full_response = ""
        sendNewPrompt = True

        while sendNewPrompt:
            sendNewPrompt = False
            tool_calls = ""
            tool_result = ""

            try:
                async with httpx.AsyncClient(timeout=None) as client:
                    async with client.stream(
                        method=request.method,
                        url=f"{OLLAMA_BASE_URL}/chat",
                        content=ollamaRequest.to_json().encode("utf-8"),
                    ) as response:

                        async for line in response.aiter_lines():
                            try:
                                if not line:
                                    continue
                                ollamaResponse = OllamaResponse.from_json(line)
                                if not ollamaResponse.model:
                                    yield {"event":"error","data": line.replace('\\"',"'")}
                                    continue

                                # accumulate assistant content
                                full_response += ollamaResponse.message.content

                                # tool call?
                                if ollamaResponse.message.toolCalls:
                                    tool_calls = json.dumps([tc.to_dict() for tc in ollamaResponse.message.toolCalls])
                                    for tc in ollamaResponse.message.toolCalls:
                                        if not tc.function.name:
                                            continue
                                        result, err = await toolInvoke(tc.function)
                                        if result:
                                            tool_result += (result if not tool_result else f" {result}")
                                            ollamaRequest.messages.append(
                                                OllamaMessage(role="tool", content=result)
                                            )
                                            sendNewPrompt = True
                                        elif err:
                                            yield {"event":"error","data":"error"}
                                        else:
                                            yield {"event":"tool_calls","data": line}
                                else:
                                    # normal token
                                    yield {"data": line}
                            except Exception:
                                yield {"event":"error","data":"error"}

                # end of one NDJSON stream → persist assistant output + tool info
                try:
                    async with main.server.pool.connection() as conn:
                        async with conn.cursor() as cur:
                            await cur.execute(
                                'INSERT INTO chatts (username, message, id, appID, toolcalls) '
                                'VALUES (%s, %s, gen_random_uuid(), %s, %s);',
                                ("assistant", re.sub(r"\s+", " ", full_response),
                                 ollamaRequest.appID, tool_calls)
                            )
                            if sendNewPrompt:
                                await cur.execute(
                                    'INSERT INTO chatts (username, message, id, appid) '
                                    'VALUES (%s, %s, gen_random_uuid(), %s);',
                                    ("tool", tool_result, ollamaRequest.appID)
                                )
                except Exception:
                    yield {"event":"error","data":"error"}

            except Exception:
                yield {"event":"error","data":"error"}

    return EventSourceResponse(ndjson_yield_sse())
