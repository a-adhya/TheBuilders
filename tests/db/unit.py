# TO RUN TESTS: PYTHONPATH=src poetry run python -m pytest tests/db/unit.py -q
import pytest
from unittest.mock import MagicMock, patch
from db.schema import Garment
from models.enums import Category, Material
from src.db.garmentstore import MakeGarmentStore, GarmentStoreError

@pytest.fixture
def sample_garment():
	return Garment(
		owner=1,
		category= Category.SHIRT,
		color="#FFFFFF",
		name="Test Shirt",
		material=Material.COTTON,
		image_url="/img/test.png"
	)
# verify we flush and add garment
def test_create_success(sample_garment):
    session = MagicMock()
    store = MakeGarmentStore(session)
    out = store.create(sample_garment)
    session.add.assert_called_once_with(sample_garment)
    session.flush.assert_called_once()
    assert out is sample_garment
    
# verify we catch DB failures
def test_create_db_failure(sample_garment):
    from sqlalchemy.exc import SQLAlchemyError
    session = MagicMock()
    session.flush.side_effect = SQLAlchemyError("boom")
    store = MakeGarmentStore(session)
    with pytest.raises(GarmentStoreError):
        store.create(sample_garment)
