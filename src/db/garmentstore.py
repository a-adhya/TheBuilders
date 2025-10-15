# db/user_store.py
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional, Protocol

from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DataError, SQLAlchemyError


from .schema import GarmentRow
from datetime import datetime, timezone

from enum import IntEnum

# --- Data Types ---
class GarmentType(IntEnum):
    SHIRT = 1
    TSHIRT = 2
    JACKET = 3
    SWEATER = 4
    JEANS = 5
    PANTS = 6
    SHORTS = 7
    SHOES = 8
    ACCESSORY = 9

class MaterialType(IntEnum):
    COTTON = 1
    DENIM = 2
    WOOL = 3
    COURDORY = 4
    SILK = 5
    SATIN = 6
    LEATHER = 7
    ATHLETIC = 8

@dataclass(frozen=True)
class Garment:
    # User ID of garment owner
    owner: int
    # Enumerated category of Garment, see GarmentType
    type: GarmentType
    # The hexcode for the color of this Garment, e.g "#A1B2C3"
    color: str
    # Human readable name, e.g "My Oxford Shirt"
    name: str
    # Primary material, see MaterialType
    material: MaterialType
    # Internal URL to image of garment
    image_url: str
    # UTC timestamp of upload time.
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    # Unique identifier for garment
    id: int | None = None


class GarmentStore(Protocol):
    def create(self, garment: Garment) -> Garment: ...

# --- Error Types ---
class GarmentError(Exception):
    """Base class for garment store errors."""

class GarmentAlreadyExists(GarmentError):
    """Unique/PK constraint violation when creating a garment."""

class GarmentValidationError(GarmentError):
    """Bad inputs (DB-level validation failures, bad enum casts, etc.)."""

class GarmentStoreError(GarmentError):
    """Unexpected storage/backend failure."""

# --- Store implementation ---
class _GarmentStore(GarmentStore):
    def __init__(self, session: Session) -> None:
        self._session = session

    @staticmethod
    def row_to_garment(row: GarmentRow | None) -> Optional[Garment]:
        if row is None:
            return None
        return Garment(
            id=row.id,
            owner=row.owner_id,
            type=GarmentType(row.type),
            color=row.color_hex,
            name=row.name,
            material=MaterialType(row.material),
            image_url=row.image_url,
            created_at=row.created_at,
        )
        
    
    @staticmethod
    def garment_to_row(garment: Garment) -> GarmentRow:
        return GarmentRow(
            # id ignored so DB auto increments
            owner_id=garment.owner,
            type=int(garment.type),
            material=int(garment.material),
            color_hex=garment.color,
            name=garment.name,
            image_url=garment.image_url,
            created_at=garment.created_at,
        )
        

    def create(self, garment: Garment) -> Garment:
        row = self.garment_to_row(garment)
        try:
            self._session.add(row)
            self._session.flush() 
        except IntegrityError as e:
            self._session.rollback()
            raise GarmentAlreadyExists("garment already exists") from e
        except (DataError, ValueError) as e:
            self._session.rollback()
            raise GarmentValidationError(str(e)) from e
        except SQLAlchemyError as e:
            self._session.rollback()
            raise GarmentStoreError("database error") from e
        return garment


# --- Public Factory  ---
def MakeGarmentStore(session: Session) -> GarmentStore:
    """
    Return a UserStore bound to the given Session.
    Callers depend on the interface (UserStore)
    """
    return _GarmentStore(session)
