"""Integration test: verify GET /api/item/get returns garments from real MySQL.

This test requires the MySQL container (docker-compose) to be running and
accessible at the DATABASE_URL configured in `api.server`.
"""
from fastapi.testclient import TestClient

from api.server import app, DATABASE_URL
from db.driver import make_engine, make_session_factory, create_tables, session_scope
from db.schema import Garment
from models.enums import Category, Material


def test_get_wardrobe_integration():
    # ensure tables exist and insert a test garment directly using SQLAlchemy
    engine = make_engine(DATABASE_URL, echo=False)
    create_tables(engine)
    SessionFactory = make_session_factory(engine)

    test_owner = 4242

    with session_scope(SessionFactory) as s:
        g = Garment(
            owner=test_owner,
            category=Category.SHIRT,
            material=Material.COTTON,
            color="#ABCDEF",
            name="Integration Shirt",
            image_url="/img/int.png",
            dirty=False,
        )
        s.add(g)
        # flush to get id assigned
        s.flush()

    # Create a TestClient and override the dependency to ensure the
    # service uses the same SessionFactory we created above (avoids timing
    # issues with the app's global SessionFactory during startup).
    client = TestClient(app)
    from api.server import get_garment_service
    from services.garment_service import DbGarmentService

    app.dependency_overrides[get_garment_service] = lambda: DbGarmentService(SessionFactory)

    resp = client.get(f"/api/item/get?user_id={test_owner}")
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body, list)
    # verify our inserted garment is present
    assert any(item.get("name") == "Integration Shirt" for item in body)

    # cleanup override
    app.dependency_overrides.clear()
