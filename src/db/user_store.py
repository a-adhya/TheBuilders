# db/user_store.py
from __future__ import annotations
from typing import Optional, Protocol, List

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from db.schema import User


class UserStore(Protocol):
    def create(self, user: User) -> User: ...
    def list_by_owner(self, owner: int) -> List[User]: ...


# --- Error Types ---
class UserError(Exception):
    """Base class for user store errors."""


class UserStoreError(UserError):
    """Unexpected storage/backend failure."""


# --- Store implementation ---
class _UserStore(UserStore):
    def __init__(self, session: Session) -> None:
        self._session = session

    def create(self, user: User) -> User:
        try:
            self._session.add(user)
            self._session.flush()
            return user
        except SQLAlchemyError as e:
            self._session.rollback()
            raise UserStoreError("database error") from e

    def get_by_username(self, username: str) -> Optional[User]:
        return (
            self._session.query(User)
            .filter(User.username == username)
            .one_or_none()
        )

    def get_by_id(self, id: int) -> Optional[User]:
        return self._session.get(User, id)

# --- Public Factory  ---
def MakeUserStore(session: Session) -> UserStore:
    """
    Return a UserStore bound to the given Session.
    Callers depend on the interface (UserStore)
    """
    return _UserStore(session)
