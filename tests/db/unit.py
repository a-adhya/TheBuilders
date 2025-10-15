# TO RUN TESTS: PYTHONPATH=src poetry run python -m pytest tests/db/unit.py -q
import pytest
from unittest.mock import MagicMock, patch
from src.db.garmentstore import Garment, GarmentType, MaterialType, MakeGarmentStore, GarmentAlreadyExists, GarmentValidationError, GarmentStoreError
from datetime import datetime, timezone

@pytest.fixture
def sample_garment():
	return Garment(
		owner=1,
		type=GarmentType.SHIRT,
		color="#FFFFFF",
		name="Test Shirt",
		material=MaterialType.COTTON,
		image_url="/img/test.png",
		created_at=datetime.now(timezone.utc),
		id=None
	)

def test_create_success(sample_garment):
	session = MagicMock()
	store = MakeGarmentStore(session)
	# Patch session.add and session.flush to simulate DB behavior
	with patch.object(session, 'add') as mock_add, patch.object(session, 'flush') as mock_flush:
		result = store.create(sample_garment)
		mock_add.assert_called_once()
		mock_flush.assert_called_once()
	assert result == sample_garment

def test_create_duplicate(sample_garment):
	session = MagicMock()
	store = MakeGarmentStore(session)
	# Patch session.add to raise IntegrityError
	with patch("src.db.garmentstore.IntegrityError", Exception):
		session.add.side_effect = Exception("IntegrityError")
		with pytest.raises(GarmentAlreadyExists):
			store.create(sample_garment)
	session.rollback.assert_called()

def test_create_validation_error(sample_garment):
	session = MagicMock()
	store = MakeGarmentStore(session)
	with patch("src.db.garmentstore.DataError", ValueError):
		session.add.side_effect = ValueError("bad value")
		with pytest.raises(GarmentValidationError):
			store.create(sample_garment)
	session.rollback.assert_called()

def test_create_db_error(sample_garment):
	session = MagicMock()
	store = MakeGarmentStore(session)
	with patch("src.db.garmentstore.SQLAlchemyError", RuntimeError):
		session.add.side_effect = RuntimeError("db error")
		with pytest.raises(GarmentStoreError):
			store.create(sample_garment)
	session.rollback.assert_called()
