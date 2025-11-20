from typing import Protocol, Optional
from api.schema import CreateUserRequest, UserResponse
from db.user_store import MakeUserStore
from db.driver import session_scope
from db.schema import User


class UserService(Protocol):
    def create(self, req: CreateUserRequest) -> UserResponse: ...
    def get_by_id(self, id: int) -> Optional[UserResponse]: ...


class DbUserService:
    def __init__(self, session_factory) -> None:
        self._session_factory = session_factory

    def _make_avatar_url(self, user_id: int) -> str:
        # deterministic avatar path in avatars bucket using user id
        return f"/avatars/user_{user_id}"

    def create(self, req: CreateUserRequest) -> UserResponse:
        with session_scope(self._session_factory) as s:
            store = MakeUserStore(s)
            # create with temporary avatar_url (non-nullable column)
            user = User(username=req.username, hashed_password=req.hashed_password, avatar_url="/avatars/temp")
            persisted = store.create(user)  # flush assigns id
            # populate deterministic avatar_url using assigned id
            persisted.avatar_url = self._make_avatar_url(persisted.id)
            # ensure change is flushed before commit
            s.flush()

            return UserResponse(
                id=persisted.id,
                username=persisted.username,
                avatar_url=persisted.avatar_url,
                created_at=persisted.created_at,
            )

    def get_by_id(self, id: int) -> Optional[UserResponse]:
        with session_scope(self._session_factory) as s:
            store = MakeUserStore(s)
            u = store.get_by_id(id)
            if u is None:
                return None
            return UserResponse(
                id=u.id,
                username=u.username,
                avatar_url=u.avatar_url,
                created_at=u.created_at,
            )
