# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/services/outfit_generator_service_tests.py -q
from services.outfit_generator_service import OutfitGeneratorService
from api.schema import GenerateOutfitRequest
import pytest


@pytest.fixture
def sample_garments():
    return [
        {
            "id": 1,
            "owner": 1,
            "category": 1,  # Using enum values as integers like in garment_service_tests
            "color": "#112233",
            "name": "Blue T-Shirt",
            "material": 1,
            "image_url": "/img/shirt.jpg",
            "dirty": False
        },
        {
            "id": 2,
            "owner": 1,
            "category": 2,
            "color": "#000000",
            "name": "Black Jeans",
            "material": 2,
            "image_url": "/img/pants.jpg",
            "dirty": False
        }
    ]


def test_generate_outfit_basic(sample_garments):
    """Test basic outfit generation with a simple context"""
    svc = OutfitGeneratorService()
    req = GenerateOutfitRequest(optional_string="casual outfit")

    result = svc.generate_outfit(sample_garments, req.optional_string)

    # We expect some garments to be returned
    assert len(result.garments) > 0
    # Verify returned garments are from our sample set
    for garment in result.garments:
        assert garment["id"] in [1, 2]


def test_generate_outfit_empty():
    """Test outfit generation with no garments"""
    svc = OutfitGeneratorService()
    req = GenerateOutfitRequest(optional_string="any outfit")

    result = svc.generate_outfit([], req.optional_string)

    # Should return empty list
    assert len(result.garments) == 0


def test_generate_outfit_with_context(sample_garments):
    """Test outfit generation with specific context"""
    svc = OutfitGeneratorService()
    req = GenerateOutfitRequest(optional_string="formal business meeting")

    result = svc.generate_outfit(sample_garments, req.optional_string)

    # We expect some garments to be returned
    assert len(result.garments) > 0
    # Verify returned garments are from our sample set
    for garment in result.garments:
        assert garment["id"] in [1, 2]
