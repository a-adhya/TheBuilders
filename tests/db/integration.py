# TO RUN TEST: PYTHONPATH=src poetry run python -m pytest tests/db/integration.py -q
import pytest
from testcontainers.mysql import MySqlContainer

from db.driver import create_tables, make_engine, make_session_factory, session_scope
from db.garment_store import MakeGarmentStore
from db.user_store import MakeUserStore
from tests.db.util import generate_random_garment
from db.schema import Garment
from models.enums import Category, Material


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
        assert output.dirty == input.dirty

        # verify DB populated fields
        assert output.id is not None
        assert output.created_at is not None


def test_update_garment(session_factory):
    """Verify that updating a persisted garment via the store persists changes."""
    with session_scope(session_factory) as s:
        store = MakeGarmentStore(s)

        # create an input garment and persist it
        input = generate_random_garment(owner=321)
        output = store.create(input)

        # modify a couple fields on the persistent object
        output.name = "Integration Updated"
        output.color = "#778899"

        # call update (store.update flushes changes)
        store.update(output)

        # re-load and verify changes
        refreshed = store.get(output.id)
        assert refreshed is not None
        assert refreshed.name == "Integration Updated"
        assert refreshed.color == "#778899"


def test_list_by_owner_returns_garments(session_factory):
    """Verify GarmentStore.list_by_owner returns garments for a given owner."""

    test_owner = 4242

    with session_scope(session_factory) as s:
        store = MakeGarmentStore(s)
        g = Garment(
            owner=test_owner,
            category=Category.SHIRT,
            material=Material.COTTON,
            color="#ABCDEF",
            name="Integration Shirt",
            image_url="/img/int.png",
            dirty=False,
        )
        store.create(g)

        garments = store.list_by_owner(test_owner)
        assert isinstance(garments, list)
        assert any(item.name == "Integration Shirt" for item in garments)
            
def test_create_user(session_factory):
    """Verify that we can create a user in the DB."""
    from db.schema import User

    with session_scope(session_factory) as s:
        store = MakeUserStore(s)
        u = User(
            username="testuser",
            hashed_password="hashedpw",
        )
        out = store.create(u)
        
        assert out.id is not None
        assert out.username == "testuser"
        
def test_delete_garment(session_factory):
    """Verify that we can delete a garment from the DB."""
    with session_scope(session_factory) as s:
        store = MakeGarmentStore(s)
        g = generate_random_garment(owner=555)
        persisted = store.create(g)
        
        # now delete
        store.delete(persisted)
        
        # verify it's gone
        fetched = store.get(persisted.id)
        assert fetched is None  
