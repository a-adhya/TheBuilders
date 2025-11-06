from http.client import HTTPException
import httpx
from starlette.background import BackgroundTask
from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse, Response, StreamingResponse

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
