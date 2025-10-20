from fastapi import FastAPI, HTTPException
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from api.schema import CreateGarmentRequest, CreateGarmentResponse
from db.driver import make_engine, make_session_factory, create_tables, session_scope
from db.garmentstore import MakeGarmentStore
from db.schema import Garment

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

@app.post("/create_garment", response_model=CreateGarmentResponse, status_code=201)
def create_garment(payload: CreateGarmentRequest):
    garment = Garment(
        owner=payload.owner,
        category=payload.category,
        color=payload.color,
        name=payload.name,
        material=payload.material,
        image_url=payload.image_url,
    )
    
    try:
        with session_scope(SessionFactory) as s:
            store = MakeGarmentStore(s)
            out = store.create(garment)
            return CreateGarmentResponse(
                owner=out.owner,
                category=int(out.category),
                color=out.color,
                name=out.name,
                material=int(out.material),
                image_url=out.image_url,
                id=out.id,
                created_at=out.created_at,
            )
    except Exception:
        raise HTTPException(status_code=500, detail="internal error")
