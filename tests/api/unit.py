# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/api/unit.py -q
from datetime import datetime, timezone
from fastapi.testclient import TestClient

from api.schema import CreateGarmentRequest, CreateGarmentResponse, ListByOwnerResponse
from api.server import app, get_garment_service
from db.schema import Garment

# API Server for Tests
client = TestClient(app)


def test_generate_outfit_unit():
    class FakeGarmentService:
        def list_by_owner(self, owner):
            # Return a single fake garment for user_id=1
            if owner == 1:
                return ListByOwnerResponse(garments=[
                    CreateGarmentResponse(
                        id=1,
                        owner=1,
                        category=1,
                        material=1,
                        color="#000000",
                        name="Unit Shirt",
                        image_url="/img/x.png",
                        dirty=False,
                        created_at=datetime.now(timezone.utc),
                    )
                ])
            return ListByOwnerResponse(garments=[])

    class FakeOutfitGeneratorService:
        def generate_outfit(self, garments, context):
            # Just return the garments as the outfit for testing
            return {"garments": [g.dict() for g in garments.garments]}

    app.dependency_overrides[get_garment_service] = lambda: FakeGarmentService(
    )
    app.dependency_overrides["services.outfit_generator_service.OutfitGeneratorService"] = lambda: FakeOutfitGeneratorService()

    payload = {"optional_string": "test context"}
    resp = client.post("/generate_outfit?user_id=1", json=payload)
    assert resp.status_code == 200
    body = resp.json()
    assert "garments" in body
    assert len(body["garments"]) == 1
    assert body["garments"][0]["name"] == "Unit Shirt"
    app.dependency_overrides.clear()


class FakeService:
    """Fake GarmentService used for unit tests."""

    def __init__(self):
        self.created = []
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
        req.id = len(self.created) + 1
        req.created_at = datetime.now(timezone.utc)
        self.created.append(req)
        return req

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

    def list_by_owner(self, owner: int):
        out = []
        if owner == 1:
            out.append(
                CreateGarmentResponse(
                    id=1,
                    owner=1,
                    category=1,
                    material=1,
                    color="#000000",
                    name="Unit Shirt",
                    image_url="/img/x.png",
                    dirty=False,
                    created_at=datetime.now(timezone.utc),
                ).dict()
            )
        return ListByOwnerResponse(garments=out)


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
        "image_url": "/img/x.png",
        "dirty": False,
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


def test_update_garment_unit():
    fake = FakeService()
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
    fake = FakeService()
    app.dependency_overrides[get_garment_service] = lambda: fake

    resp = client.get("/api/item/get?user_id=1")
    assert resp.status_code == 200
    body = resp.json()
    assert "garments" in body
    assert isinstance(body["garments"], list)
    assert len(body["garments"]) == 1
    assert body["garments"][0]["owner"] == 1
    assert body["garments"][0]["name"] == "Unit Shirt"
    app.dependency_overrides.clear()
