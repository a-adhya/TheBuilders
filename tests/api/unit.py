# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/api/unit.py -q
from datetime import datetime, timezone
from fastapi.testclient import TestClient

from api.schema import (
    CreateGarmentRequest,
    CreateGarmentResponse,
    ListByOwnerResponse,
    DeleteGarmentResponse,
)
from api.server import app, get_garment_service
from db.schema import Garment

# API Server for Tests
client = TestClient(app)

# FakeGarmentService used for unit tests
class FakeGarmentService:
    def __init__(self):
        # Use an in-memory dict keyed by id to simulate persistence
        # for update test: a simple in-memory dict
        self.store = {
            1: {
                "id": 1,
                "owner": 1,
                "category": 1,
                "color": "#000000",
                "name": "Unit Shirt",
                "material": 1,
                "image_url": "/img/x.png",
                "dirty": False,
                "created_at": datetime.now(timezone.utc),
            }
        }

    def create(self, req: CreateGarmentRequest) -> CreateGarmentResponse:
        # Accept either a DB Garment-like object or a Pydantic request object.
        # Determine the next id
        next_id = max(self.store.keys()) + 1 if self.store else 1

        # Build the record from available attributes
        rec = {
            "id": next_id,
            "owner": getattr(req, "owner", None),
            "category": getattr(req, "category", None),
            "color": getattr(req, "color", None),
            "name": getattr(req, "name", None),
            "material": getattr(req, "material", None),
            "image_url": getattr(req, "image_url", None),
            "dirty": getattr(req, "dirty", False),
            "created_at": datetime.now(timezone.utc),
        }

        # persist to the in-memory store
        self.store[next_id] = rec

        # return a response model instance
        return CreateGarmentResponse(**rec)

    def update(self, id: int, req):
        if id not in self.store:
            raise ValueError("not found")
        rec = self.store[id]
        # update only provided fields (pydantic model will have attributes)
        for field in ["owner", "category", "color", "name", "material", "image_url", "dirty"]:
            val = getattr(req, field, None)
            if val is not None:
                rec[field] = val
        # return an object that matches CreateGarmentResponse
        return CreateGarmentResponse(**rec)

    def delete(self, id: int):
        # delete the record from the in-memory store and return a response
        if id not in self.store:
            raise ValueError("not found")
        rec = self.store.pop(id)

        return DeleteGarmentResponse(**rec)

    def list_by_owner(self, owner: int):
        out = []
        for rec in self.store.values():
            if rec.get("owner") == owner:
                # create response model from stored dict; ensure created_at is present
                out.append(CreateGarmentResponse(**rec).dict())

        return ListByOwnerResponse(garments=out)

def test_create_garment_unit():
    fake = FakeGarmentService()
    # override the dependency used by the app
    app.dependency_overrides[get_garment_service] = lambda: fake

    payload = {
        "owner": 1,
        "category": 1,
        "color": "#000000",
        "name": "Unit Shirt",
        "material": 1,
        "image_url": "/img/x.png",
        "dirty": False,
    }

    resp = client.post("/garments", json=payload)
    assert resp.status_code == 201
    body = resp.json()

    # verify response mapped values and that id was assigned by the fake store
    assert body["id"] is not None
    assert body["name"] == "Unit Shirt"
    assert body["owner"] == 1
    # cleanup dependency overrides
    app.dependency_overrides.clear()


def test_delete_garment_unit():
    fake = FakeGarmentService()

    # Isolate this test by creating our own item
    test_id = 9999
    fake.store = {
        test_id: {
            "id": test_id,
            "owner": 1,
            "category": 1,
            "color": "#ABCDEF",
            "name": "Delete Me",
            "material": 1,
            "image_url": "/img/delete.png",
            "dirty": False,
            "created_at": datetime.now(timezone.utc),
        }
    }

    app.dependency_overrides[get_garment_service] = lambda: fake

    # call the new path-based delete endpoint
    resp = client.delete(f"/garments/{test_id}")
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == test_id

    # ensure the item is gone from the wardrobe
    resp2 = client.get("/garments/1")
    assert resp2.status_code == 200
    body2 = resp2.json()
    assert isinstance(body2["garments"], list)
    assert len(body2["garments"]) == 0

    app.dependency_overrides.clear()

def test_update_garment_unit():
    fake = FakeGarmentService()
    app.dependency_overrides[get_garment_service] = lambda: fake

    payload = {
        "name": "Updated Shirt",
        "color": "#112233"
    }

    resp = client.patch("/garments/1", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == 1
    assert body["name"] == "Updated Shirt"
    assert body["color"].upper() == "#112233"

    app.dependency_overrides.clear()


def test_get_wardrobe_by_user():
    fake = FakeGarmentService()
    app.dependency_overrides[get_garment_service] = lambda: fake

    resp = client.get("/garments/1")
    assert resp.status_code == 200
    body = resp.json()
    assert "garments" in body
    assert isinstance(body["garments"], list)
    assert len(body["garments"]) == 1
    assert body["garments"][0]["owner"] == 1
    assert body["garments"][0]["name"] == "Unit Shirt"
    app.dependency_overrides.clear()
