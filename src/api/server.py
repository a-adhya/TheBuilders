from fastapi import FastAPI, HTTPException
from contextlib import asynccontextmanager

from api.schema import (
    CreateGarmentRequest,
    CreateGarmentResponse,
    DeleteGarmentRequest, DeleteGarmentResponse, UpdateGarmentRequest,
    ListByOwnerResponse,
    GenerateOutfitRequest,
    GenerateOutfitResponse,
    ChatRequest,
    ChatResponse,
)
from api.validate import validate_create_garment_request, validate_update_garment_request
from db.driver import make_engine, make_session_factory, create_tables
from db.schema import Garment
from fastapi import Depends
from services.garment_service import GarmentService, DbGarmentService
from models.enums import Category
from services.outfit_generator_service import OutfitGeneratorService
from services.chat_service import ChatService
from typing import List, Optional
from dotenv import load_dotenv
import os

from sqlalchemy.exc import OperationalError

# Hard-coded DATABASE_URL for local development (connects to the MySQL container)
DATABASE_URL = "mysql+pymysql://apiuser:apipass@127.0.0.1:3306/testdb"

# We'll create the engine and session factory at startup so failures are surfaced clearly.
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


@app.post("/create_garment", response_model=CreateGarmentResponse, status_code=201)
def create_garment(
    payload: CreateGarmentRequest, svc: GarmentService = Depends(get_garment_service)
):
    validate_create_garment_request(payload)
    garment = Garment(
        owner=payload.owner,
        category=payload.category,
        color=payload.color,
        name=payload.name,
        material=payload.material,
        image_url=payload.image_url,
        dirty=payload.dirty,
    )

    try:
        out = svc.create(garment)
        return out
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.patch("/garments/{id}", response_model=CreateGarmentResponse)
def update_garment(
    id: int, payload: UpdateGarmentRequest, svc: GarmentService = Depends(get_garment_service)
):
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


# Get Clothing Items

# Endpoint: /api/item/get
# Method: GET
# Description: Retrieve clothing items (optionally filtered by user, tag, item type).
# Example Request:
# GET /api/item/get?user_id=5&type=top
# Example Response:
# {
#   "items": [
#     <clothing object>,
#     ...
#   ]
# }
# Response Codes:
# 200 – Success
# 404 – No items found
# 401 – Unauthorized

@app.get("/api/item/get", response_model=ListByOwnerResponse, status_code=200)
def getWardrobe(user_id: int, category: Optional[Category] = None, svc: GarmentService = Depends(get_garment_service)):
    """
    Retrieve clothing items filtered by user id.

    Query parameters:
    - user_id (int): required. Returns all garments owned by the user.
    """

    if user_id is None:
        raise HTTPException(
            status_code=400, detail="user_id query parameter is required")

    try:
        response = svc.list_by_owner(user_id)
        if not response.garments:
            # return empty response with 200
            return ListByOwnerResponse(garments=[], category=category)
        return response
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.post("/generate_outfit", response_model=GenerateOutfitResponse)
def generate_outfit(
    payload: GenerateOutfitRequest,
    user_id: Optional[int] = None,
    svc: GarmentService = Depends(get_garment_service),
    outfit_generator: OutfitGeneratorService = Depends(
        lambda: OutfitGeneratorService())
):
    if user_id is None:
        raise HTTPException(
            status_code=400, detail="user_id query parameter is required")

    try:
        garments = svc.list_by_owner(user_id)
        if not garments.garments:
            garments = ListByOwnerResponse(garments=[])

        context = payload.optional_string if payload.optional_string else "No additional context provided."

        return outfit_generator.generate_outfit(garments, context)
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.post("/chat", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
    chat_svc: ChatService = Depends(get_chat_service),
):
    """Chat endpoint that accepts a conversation history and optional system prompt.

    Request body example:
    {
      "messages": [{"role": "user", "content": "Hello"}],
      "system": "You are a helpful assistant."
    }
    """
    try:
        if not payload.messages or not isinstance(payload.messages, list):
            raise HTTPException(
                status_code=400, detail="messages is required and must be a list")

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
    
@app.delete("/delete_garment", response_model=DeleteGarmentResponse)
def delete_garment(
    payload: DeleteGarmentRequest,
    svc: GarmentService = Depends(get_garment_service)
):
    try:
        out = svc.delete(payload.id)
        return out
    except ValueError:
        # not found
        raise HTTPException(status_code=404, detail="garment not found")
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")
