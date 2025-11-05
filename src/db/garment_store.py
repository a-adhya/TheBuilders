# db/user_store.py
from __future__ import annotations
from typing import Protocol, List

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from .schema import Garment


class GarmentStore(Protocol):
    def create(self, garment: Garment) -> Garment: ...
    def get(self, id: int) -> Garment | None: ...
    def update(self, garment: Garment) -> Garment: ...
    def delete(self, garment: Garment) -> None: ...
    def list_by_owner(self, owner: int) -> List[Garment]: ...


class GarmentError(Exception):
    """Base class for garment store errors."""


class GarmentStoreError(GarmentError):
    """Unexpected storage/backend failure."""


class _GarmentStore(GarmentStore):
    def __init__(self, session: Session) -> None:
        self._session = session

    def create(self, garment: Garment) -> Garment:
        try:
            self._session.add(garment)
            self._session.flush()
        except SQLAlchemyError as e:
            self._session.rollback()
            raise GarmentStoreError("database error") from e
        return garment

    def get(self, id: int) -> Garment | None:
        return self._session.get(Garment, id)

    def update(self, garment: Garment) -> Garment:
        try:
            self._session.flush()
        except SQLAlchemyError as e:
            self._session.rollback()
            raise GarmentStoreError("database error") from e
        return garment

    def list_by_owner(self, owner: int) -> List[Garment]:
        try:
            results = self._session.query(Garment).filter_by(owner=owner).all()
        except SQLAlchemyError as e:
            raise GarmentStoreError("database error") from e
        return results

    def delete(self, garment: Garment) -> None:
        try:
            self._session.delete(garment)
            self._session.flush()
        except SQLAlchemyError as e:
            self._session.rollback()
            raise GarmentStoreError("database error") from e


def MakeGarmentStore(session: Session) -> GarmentStore:
    return _GarmentStore(session)
