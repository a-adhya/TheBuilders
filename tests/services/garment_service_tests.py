# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/services/garment_service_tests.py -q
from db.driver import make_engine, make_session_factory, create_tables
from services.garment_service import DbGarmentService
from api.schema import CreateGarmentRequest
from sqlalchemy import select
import pytest


@pytest.fixture
def sqlite_session_factory():
    engine = make_engine("sqlite+pysqlite:///:memory:", echo=False)
    create_tables(engine)
    return make_session_factory(engine)


def test_db_garment_service_persists(sqlite_session_factory):
    svc = DbGarmentService(sqlite_session_factory)

    req = CreateGarmentRequest(
        owner=1,
        category=1,
        color="#112233",
        name="Integration",
        material=1,
        image_url="/img/int.png",
    )

    out = svc.create(req)

    assert out.id is not None
    assert out.created_at is not None
    assert out.name == "Integration"
    assert out.color.upper() == "#112233"
    assert out.owner == 1