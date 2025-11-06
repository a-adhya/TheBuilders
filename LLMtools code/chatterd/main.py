import handlers
from starlette.applications import Starlette
from starlette.routing import Route
from contextlib import asynccontextmanager
from psycopg_pool import AsyncConnectionPool

# must include the trailing '/'
routes = [
    Route('/llmprompt', handlers.llmprompt, methods=['POST']),
    Route('/llmtools', handlers.llmtools, methods=['POST']),
    Route('/weather', handlers.weather, methods=['GET']),
    ]

@asynccontextmanager
async def lifespan(server):
    server.pool = AsyncConnectionPool("dbname=chatterdb user=chatter password=chattchatt host=localhost", open=False)
    await server.pool.open()
    yield
    await server.pool.close()

# must come after route definitions
server = Starlette(routes=routes, lifespan=lifespan)

