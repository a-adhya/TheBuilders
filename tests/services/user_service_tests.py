# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/services/user_service_tests.py -q
from services.user_service import DbUserService
from db.driver import make_session_factory, create_tables
from sqlalchemy import create_engine as _create_engine
from api.schema import CreateUserRequest


def test_db_user_service_create_sqlite(tmp_path):
    # Use a temporary sqlite file to exercise the DbUserService
    dbfile = tmp_path / "users.sqlite"
    engine = _create_engine(f"sqlite:///{dbfile}")
    create_tables(engine)
    Session = make_session_factory(engine)

    svc = DbUserService(Session)

    # construct a real CreateUserRequest
    req = CreateUserRequest(username="integration_user", hashed_password="hpw")

    resp = svc.create(req)
    assert resp.id is not None
    assert resp.username == "integration_user"
    assert resp.avatar_url == f"/avatars/user_{resp.id}"
