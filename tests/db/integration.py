# TO RUN TEST: PYTHONPATH=src poetry run python -m pytest tests/db/integration.py -q
import pytest
from testcontainers.mysql import MySqlContainer

from db.driver import create_tables, make_engine, make_session_factory, session_scope
from db.garmentstore import MakeGarmentStore
from tests.db.util import generate_random_garment

@pytest.fixture(scope="session")
def mysql_url():
    with MySqlContainer("mysql:8.0", root_password="rootpw", dbname="testdb") as mysql:
        url = mysql.get_connection_url() 
        # force TCP instead of UNIX socket for mysqlclient/MySQLdb
        url = url.replace("@localhost:", "@127.0.0.1:")
        yield url  # container lives for the duration of the session

@pytest.fixture(scope="session")
def engine(mysql_url):
    eng = make_engine(mysql_url, echo=False)
    create_tables(eng)
    return eng

@pytest.fixture
def session_factory(engine):
    return make_session_factory(engine)

def test_create_garment(session_factory):
    with session_scope(session_factory) as s:
        store = MakeGarmentStore(s)
        input = generate_random_garment(owner = 123)
        output = store.create(input)
        
        assert input == output
