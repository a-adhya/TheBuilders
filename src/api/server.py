from fastapi import FastAPI, HTTPException
from contextlib import asynccontextmanager

from api.schema import (
    CreateGarmentRequest,
    CreateGarmentResponse,
    DeleteGarmentResponse,
    UpdateGarmentRequest,
    ListByOwnerResponse,
    GenerateOutfitRequest,
    GenerateOutfitResponse,
    ChatRequest,
    ChatResponse,
    CreateUserRequest,
    UserResponse,
)
from api.validate import (
    validate_create_garment_request,
    validate_update_garment_request,
)
from db.driver import make_engine, make_session_factory, create_tables
from db.schema import Garment
from fastapi import Depends
from services.garment_service import GarmentService, DbGarmentService
from services.outfit_generator_service import OutfitGeneratorService
from services.chat_service import ChatService
from services.user_service import UserService, DbUserService

from sqlalchemy.exc import OperationalError

# Hard-coded DATABASE_URL for local development (connects to the MySQL container)
DATABASE_URL = "mysql+pymysql://apiuser:apipass@127.0.0.1:3306/testdb"

engine = None
SessionFactory = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global engine, SessionFactory
    try:
        engine = make_engine(DATABASE_URL, echo=False)
        SessionFactory = make_session_factory(engine)
        # verify connectivity
        with engine.connect() as conn:
            pass
    except OperationalError as e:
        raise RuntimeError(
            f"Unable to connect to database using DATABASE_URL={DATABASE_URL!r}: {e}\n"
            "Please ensure that you have a MySQL container running, the URL is correct, and the user has privileges.\n"
        ) from e

    # ensure schema is present (idempotent)
    create_tables(engine)
    yield


app = FastAPI(lifespan=lifespan)


def get_garment_service() -> GarmentService:
    return DbGarmentService(SessionFactory)


def get_chat_service() -> ChatService:
    return ChatService()


def get_outfit_generator_service() -> OutfitGeneratorService:
    return OutfitGeneratorService()


def get_user_service() -> UserService:
    return DbUserService(SessionFactory)


@app.post("/garments", response_model=CreateGarmentResponse, status_code=201)
def create_garment(
    payload: CreateGarmentRequest, svc: GarmentService = Depends(get_garment_service)
):
    """
    Create a new garment.

    Request body:
    - owner (int): user id owning the garment.
    - category (int): category id.
    - color (str): hex color (e.g. "#000000").
    - name (str): garment name.
    - material (int): material id.
    - dirty (bool): is the garment dirty.
    """

    validate_create_garment_request(payload)

    try:
        out = svc.create(payload)
        return out
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.patch("/garments/{id}", response_model=CreateGarmentResponse, status_code=200)
def update_garment(
    id: int,
    payload: UpdateGarmentRequest,
    svc: GarmentService = Depends(get_garment_service),
):
    """
    Update an existing garment.

    Path parameter:
    - id (int): garment id to update.

    Request body (UpdateGarmentRequest; fields optional):
    - owner (int)
    - category (int)
    - color (str) e.g. "#000000"
    - name (str)
    - material (int)
    - image_url (str)
    - dirty (bool)
    """
    # validate partial fields
    validate_update_garment_request(payload)
    try:
        out = svc.update(id, payload)
        return out
    except ValueError:
        # not found
        raise HTTPException(status_code=404, detail="garment not found")
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.get("/garments/{user_id}", response_model=ListByOwnerResponse, status_code=200)
def get_garments_by_user(
    user_id: int,
    svc: GarmentService = Depends(get_garment_service),
):
    """
    Retrieve clothing items filtered by user id.

    Query parameters:
    - user_id (int): required. Returns all garments owned by the user.
    """

    try:
        response = svc.list_by_owner(user_id)
        if not response.garments:
            # return empty response with 200
            return ListByOwnerResponse(garments=[])
        return response
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.post("/generate/{user_id}", response_model=GenerateOutfitResponse)
def generate_outfit(
    user_id: int,
    payload: GenerateOutfitRequest,
    svc: GarmentService = Depends(get_garment_service),
    outfit_generator: OutfitGeneratorService = Depends(get_outfit_generator_service),
):
    """
    Generate an outfit for the given user.

    Path parameter:
    - user_id (int): user id to generate the outfit for.

    Request body:
    - optional_string (str, optional): additional context to guide outfit generation.
    """

    try:
        garments = svc.list_by_owner(user_id)
        if not garments.garments:
            garments = ListByOwnerResponse(garments=[])

        context = (
            payload.optional_string
            if payload.optional_string
            else "No additional context provided."
        )

        return outfit_generator.generate_outfit(garments, context)
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.post("/chat", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
    chat_svc: ChatService = Depends(get_chat_service),
):
    """
    Chat endpoint.

    Request body:
    - messages (list): conversation messages [{'role': str, 'content': str}].

    Response:
    - ChatResponse: generated response text.
    """

    try:
        if not payload.messages or not isinstance(payload.messages, list):
            raise HTTPException(
                status_code=400, detail="messages is required and must be a list"
            )

        resp_text = chat_svc.generate_response(
            # using model_dump() instead of deprecated dict()
            messages=[m.model_dump() for m in payload.messages]
        )
        return ChatResponse(response=resp_text)
    except HTTPException:
        raise
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.delete("/garments/{id}", response_model=DeleteGarmentResponse)
def delete_garment(id: int, svc: GarmentService = Depends(get_garment_service)):
    """
    Delete an existing garment.

    Path parameter:
    - id (int): garment id to delete.
    """
    try:
        out = svc.delete(id)
        return out
    except ValueError:
        # not found
        raise HTTPException(status_code=404, detail="garment not found")
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.post("/users", response_model=UserResponse, status_code=201)
def create_user(payload: CreateUserRequest, svc: UserService = Depends(get_user_service)):
    """
    Create a user.

    Request body:
    - username (string).
    - hashed_password (string).
    """
    try:
        out = svc.create(payload)
        return out
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")
