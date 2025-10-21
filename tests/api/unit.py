# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/api/unit.py -q 
from datetime import datetime, timezone
from fastapi.testclient import TestClient

from api.schema import CreateGarmentRequest, CreateGarmentResponse
from api.server import app, get_garment_service
from db.schema import Garment

# API Server for Tests
client = TestClient(app)

class FakeService:
    """Fake GarmentService used for unit tests."""
    def __init__(self):
        self.created = []

    def create(self, req: CreateGarmentRequest) -> CreateGarmentResponse:
        req.id = len(self.created) + 1
        req.created_at = datetime.now(timezone.utc)
        self.created.append(req)
        return req

def test_create_garment_unit():
    fake = FakeService()
    # override the dependency used by the app
    app.dependency_overrides[get_garment_service] = lambda: fake

    payload = {
        "owner": 1,
        "category": 1,
        "color": "#000000",
        "name": "Unit Shirt",
        "material": 1,
        "image_url": "/img/x.png"
    }

    resp = client.post("/create_garment", json=payload)
    assert resp.status_code == 201
    body = resp.json()

    # verify response mapped values and that id was assigned by the fake store
    assert body["id"] == 1
    assert body["name"] == "Unit Shirt"
    assert body["owner"] == 1
    # cleanup dependency overrides
    app.dependency_overrides.clear()