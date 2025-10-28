# db/user_store.py
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Protocol, List

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from .schema import Garment


class GarmentStore(Protocol):
    def create(self, garment: Garment) -> Garment: ...
    def list_by_owner(self, owner: int) -> List[Garment]: ...


# --- Error Types ---
class GarmentError(Exception):
    """Base class for garment store errors."""


class GarmentStoreError(GarmentError):
    """Unexpected storage/backend failure."""


# --- Store implementation ---
class _GarmentStore(GarmentStore):
    def __init__(self, session: Session) -> None:
        self._session = session

    def create(self, garment: Garment) -> Garment:
        try:
            self._session.add(garment)
            # must flush to get assigned ID (force transaction through)
            self._session.flush()
        except SQLAlchemyError as e:
            self._session.rollback()
            raise GarmentStoreError("database error") from e
        return garment

    def list_by_owner(self, owner: int) -> List[Garment]:
        try:
            # Use a simple query to return all garments for the owner
            results = (
                self._session.query(Garment).filter_by(owner=owner).all()
            )
        except SQLAlchemyError as e:
            raise GarmentStoreError("database error") from e
        return results


# --- Public Factory  ---
def MakeGarmentStore(session: Session) -> GarmentStore:
    """
    Return a UserStore bound to the given Session.
    Callers depend on the interface (UserStore)
    """
    return _GarmentStore(session)
