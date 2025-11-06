import handlers
from starlette.applications import Starlette
from starlette.routing import Route

# must include the trailing '/'
routes = [
    Route('/llmprompt', handlers.llmprompt, methods=['POST']),
]

# must come after route definitions
server = Starlette(routes=routes)

