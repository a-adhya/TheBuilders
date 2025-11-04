# TO RUN TESTS: PYTHONPATH=src poetry run python -m pytest tests/db/unit.py -q
import pytest
from unittest.mock import MagicMock, patch
from db.schema import Garment, User
from db.user_store import MakeUserStore, UserStoreError
from models.enums import Category, Material
from db.garment_store import MakeGarmentStore, GarmentStoreError
from sqlalchemy.exc import SQLAlchemyError

@pytest.fixture
def sample_garment():
    return Garment(
        owner=1,
        category=Category.SHIRT,
        color="#FFFFFF",
        name="Test Shirt",
        material=Material.COTTON,
        image_url="/img/test.png",
    )
    
@pytest.fixture
def sample_user():
    return User(
        username="alice",
        hashed_password="dummyhash",
    )


# verify we flush and add garment
def test_create_garment_success(sample_garment):
    session = MagicMock()
    store = MakeGarmentStore(session)
    out = store.create(sample_garment)
    session.add.assert_called_once_with(sample_garment)
    session.flush.assert_called_once()
    assert out is sample_garment


# verify we catch DB failures
def test_create_garment_db_failure(sample_garment):
    session = MagicMock()
    session.flush.side_effect = SQLAlchemyError("boom")
    store = MakeGarmentStore(session)
    with pytest.raises(GarmentStoreError):
        store.create(sample_garment)
        
def test_delete_garment_success(sample_garment):
    session = MagicMock()
    store = MakeGarmentStore(session)
    store.delete(sample_garment)
    session.delete.assert_called_once_with(sample_garment)
    session.flush.assert_called_once()

def test_delete_garment_db_failure(sample_garment):
    session = MagicMock()
    session.flush.side_effect = SQLAlchemyError("boom")
    store = MakeGarmentStore(session)
    with pytest.raises(GarmentStoreError):
        store.delete(sample_garment)
        
def test_create_user_success(sample_user):
    session = MagicMock()
    store = MakeUserStore(session)
    out = store.create(sample_user)

    session.add.assert_called_once_with(sample_user)
    session.flush.assert_called_once()
    assert out is sample_user
    
def test_create_user_db_failure(sample_user):
    session = MagicMock()
    session.flush.side_effect = SQLAlchemyError("boom")
    store = MakeUserStore(session)

    with pytest.raises(UserStoreError):
        store.create(sample_user)

    session.rollback.assert_called_once()
