# TO RUN TEST: PYTHONPATH=src poetry run python -m pytest tests/db/integration.py -q
import pytest
from testcontainers.mysql import MySqlContainer

from db.driver import create_tables, make_engine, make_session_factory, session_scope
from db.garment_store import MakeGarmentStore
from tests.db.util import generate_random_garment


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


# verify we create garment in DB and fields are populated correctly, including DB populated fields
def test_create_garment(session_factory):
    with session_scope(session_factory) as s:
        store = MakeGarmentStore(s)
        input = generate_random_garment(owner=123)
        output = store.create(input)

        assert output.owner == input.owner
        assert output.category == input.category
        assert output.color == input.color
        assert output.name == input.name
        assert output.material == input.material
        assert output.image_url == input.image_url

        # verify DB populated fields
        assert output.id is not None
        assert output.created_at is not None
