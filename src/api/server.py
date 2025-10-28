from fastapi import FastAPI, HTTPException
from contextlib import asynccontextmanager

from api.schema import CreateGarmentRequest, CreateGarmentResponse, UpdateGarmentRequest
from api.validate import validate_create_garment_request, validate_update_garment_request
from db.driver import make_engine, make_session_factory, create_tables
from db.schema import Garment
from fastapi import Depends
from services.garment_service import GarmentService, DbGarmentService

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
