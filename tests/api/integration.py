# TO RUN TEST: PYTHONPATH=src poetry run python -m pytest tests/api/integration.py -q
import pytest
from testcontainers.mysql import MySqlContainer
from fastapi.testclient import TestClient

from db.driver import create_tables, make_engine, make_session_factory, session_scope
from db.garment_store import MakeGarmentStore
from db.schema import Garment
from models.enums import Category, Material
from api.server import app, get_garment_service
from services.garment_service import DbGarmentService


@pytest.fixture(scope="session")
def mysql_url():
    with MySqlContainer("mysql:8.0", root_password="rootpw", dbname="testdb") as mysql:
        mysql.with_env("TZ", "UTC")
        url = mysql.get_connection_url()
        # force TCP instead of UNIX socket
        url = url.replace("@localhost:", "@127.0.0.1:")
        # ensure SQLAlchemy uses the PyMySQL driver
        if url.startswith("mysql://"):
            url = url.replace("mysql://", "mysql+pymysql://", 1)
        yield url


@pytest.fixture(scope="session")
def engine(mysql_url):
    eng = make_engine(mysql_url, echo=False)
    create_tables(eng)
    return eng


@pytest.fixture
def session_factory(engine):
    return make_session_factory(engine)


def test_generate_outfit_integration(session_factory):
    """Integration test for /generate_outfit endpoint with real DB."""
    test_owner = 5555
    with session_scope(session_factory) as s:
        store = MakeGarmentStore(s)
        g = Garment(
            owner=test_owner,
            category=Category.SHIRT,
            material=Material.COTTON,
            color="#123456",
            name="IntegrationTest Shirt",
            image_url="/img/inttest.png",
            dirty=False,
        )
        store.create(g)

    # Patch the dependency to use the test session factory
    app.dependency_overrides[get_garment_service] = lambda: DbGarmentService(
        session_factory)
    client = TestClient(app)
    payload = {"optional_string": "integration context"}
    resp = client.post(f"/generate_outfit?user_id={test_owner}", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert "garments" in body
    assert any(item["name"] ==
               "IntegrationTest Shirt" for item in body["garments"])
    app.dependency_overrides.clear()
