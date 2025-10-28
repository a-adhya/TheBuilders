# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/services/garment_service_tests.py -q
from db.driver import make_engine, make_session_factory, create_tables
from services.garment_service import DbGarmentService
from api.schema import CreateGarmentRequest, UpdateGarmentRequest
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
        dirty=False,
    )

    out = svc.create(req)

    assert out.id is not None
    assert out.created_at is not None
    assert out.name == "Integration"
    assert out.color.upper() == "#112233"
    assert out.owner == 1
    assert out.dirty == False


def test_db_garment_service_update(sqlite_session_factory):
    """Verify that DbGarmentService.update applies partial updates and persists them."""
    svc = DbGarmentService(sqlite_session_factory)

    # create initial garment
    req = CreateGarmentRequest(
        owner=1,
        category=1,
        color="#112233",
        name="To Update",
        material=1,
        image_url="/img/update.png",
        dirty=False,
    )

    out = svc.create(req)
    gid = out.id

    # perform partial update (change name and color)
    upd = UpdateGarmentRequest(name="Updated Name", color="#445566")
    updated = svc.update(gid, upd)

    assert updated.id == gid
    assert updated.name == "Updated Name"
    assert updated.color.upper() == "#445566"
    # unchanged fields remain
    assert updated.owner == out.owner
    assert updated.image_url == out.image_url
