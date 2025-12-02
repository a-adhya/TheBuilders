
from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Response


from contextlib import asynccontextmanager

from src.api.schema import (
    CreateGarmentRequest,
    CreateGarmentResponse,
    DeleteGarmentResponse,
    UpdateGarmentRequest,
    ListByOwnerResponse,
    GenerateOutfitRequest,
    GenerateOutfitResponse,
    ChatRequest,
    ChatResponse,

    AvatarUploadResponse,
    ClassifyImageResponse, 
    TryOnImageRequest
)
from src.api.validate import (
    validate_create_garment_request,
    validate_update_garment_request,
)
from src.db.driver import make_engine, make_session_factory, create_tables
from src.db.schema import Garment
from src.services.garment_service import GarmentService, DbGarmentService
from src.services.outfit_generator_service import OutfitGeneratorService
from src.services.chat_service import ChatService
from src.services.avatar_service import AvatarService
from src.services.classification_service import ClothingClassificationService, get_classification_service
from minio import Minio

from sqlalchemy.exc import OperationalError

# Hard-coded DATABASE_URL for local development (connects to the MySQL container)
DATABASE_URL = "mysql+pymysql://apiuser:apipass@127.0.0.1:3306/testdb"

engine = None
SessionFactory = None
minio_client = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global engine, SessionFactory, minio_client
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
    
    try:
        minio_client = Minio("127.0.0.1:9000", access_key="minioadmin", secret_key="minioadmin123", secure=False)
    except Exception:
        raise RuntimeError(
            "Unable to connect to MinIO at 127.0.0.1:9000. "
            "Please ensure that the MinIO server is running, the URL is correct, and the access credentials are valid.\n"
        ) from e
            
    yield


app = FastAPI(lifespan=lifespan)


@app.get("/health")
def health_check():
    """Health check endpoint for monitoring and testing."""
    return {"status": "healthy", "service": "clothing-classification-api"}


def get_garment_service() -> GarmentService:
    return DbGarmentService(SessionFactory)


def get_chat_service() -> ChatService:
    return ChatService()


def get_outfit_generator_service() -> OutfitGeneratorService:
    return OutfitGeneratorService()


def get_avatar_service() -> AvatarService:
    return AvatarService(SessionFactory, minio=minio_client)


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
    outfit_generator: OutfitGeneratorService = Depends(
        get_outfit_generator_service),
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
        context = (
            payload.optional_string
            if payload.optional_string
            else "No additional context provided."
        )

        return outfit_generator.generate_outfit(garments, context, payload.previous_messages)
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


@app.post("/users/{user_id}/avatar", response_model=AvatarUploadResponse)
async def upload_avatar(
    user_id: int,
    image: UploadFile = File(...),
    svc: AvatarService = Depends(get_avatar_service),
):
    """
    Accept raw image bytes, generate an avatar-like image via Gemini, upload
    to MinIO under a deterministic key, and update the user's `avatar_url`.
    Returns a JSON object with the CDN link: `{ "avatar_url": "/avatars/{id}.png" }`.
    """
    try:
        content = await image.read()
        avatar_path = svc.generate_and_upload(user_id, content)
        
        return AvatarUploadResponse(avatar_url=avatar_path)
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="internal error")


@app.post("/classify-image", response_model=ClassifyImageResponse)
async def classify_image(
    image: UploadFile = File(...),
    svc: ClothingClassificationService = Depends(get_classification_service),
):
    """
    Classify a clothing item image to detect clothing type and color.
    
    Request:
    - image: Image file (JPEG, PNG, etc.)
    
    Response:
    - category: Detected clothing category (Category enum value)
    - category_confidence: Confidence score for category prediction (0-1)
    - color: Detected color as hex string (e.g. "#FF0000")
    - color_confidence: Confidence score for color prediction (0-1)
    - success: Whether classification was successful
    - error: Error message if classification failed
    """
    try:
        # Validate file type
        if not image.content_type or not image.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Read image content
        content = await image.read()
        
        # Perform classification
        results = svc.classify_image(content)
        
        return ClassifyImageResponse(**results)
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in image classification endpoint: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
@app.post("/users/{user_id}/tryon")
def tryon_preview(
    user_id: int,
    payload: TryOnImageRequest,
    svc: AvatarService = Depends(get_avatar_service),
):
    """Separate try-on preview endpoint that does NOT reuse existing try-on schemas.

    Request body example: `{ "garments": [1, 2, 3] }`
    Returns raw `image/png` bytes.
    """
    try:
        img_bytes = svc.try_on(user_id, payload.garments)
        return Response(content=img_bytes, media_type="image/png")
    except Exception as e:
        # Unexpected/server error
        print(e)
        raise HTTPException(status_code=500, detail="internal error")
