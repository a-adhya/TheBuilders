from typing import Protocol, List
from api.schema import CreateGarmentRequest, UpdateGarmentRequest, GarmentResponse, ListByOwnerResponse
from db.garment_store import MakeGarmentStore
from db.driver import session_scope
from db.schema import Garment


class GarmentService(Protocol):
    def create(self, req: CreateGarmentRequest) -> GarmentResponse: ...
    def list_by_owner(self, owner: int) -> ListByOwnerResponse: ...


class DbGarmentService:
    """Service implementation that uses DB. This sits between the API layer and DB layer
    This layer will handle the business logic. The API layer handles the routing / validation.
    The DB Layer handles the storage / persistence of objects.
    """

    def __init__(self, session_factory) -> None:
        self._session_factory = session_factory

    def create(self, req: CreateGarmentRequest) -> GarmentResponse:
        with session_scope(self._session_factory) as s:
            store = MakeGarmentStore(s)
            garment = Garment(
                owner=req.owner,
                category=req.category,
                material=req.material,
                color=req.color,
                name=req.name,
                image_url=req.image_url,
            )
            persisted = store.create(garment)

            return GarmentResponse(
                id=persisted.id,
                owner=persisted.owner,
                category=persisted.category,
                material=persisted.material,
                color=persisted.color,
                name=persisted.name,
                image_url=persisted.image_url,
                dirty=persisted.dirty,
                created_at=persisted.created_at,
            )
    def update(self, id: int, req: UpdateGarmentRequest) -> GarmentResponse:
        with session_scope(self._session_factory) as s:
            store = MakeGarmentStore(s)
            garment = store.get(id)
            if garment is None:
                # service-level not-found signal
                raise ValueError("garment not found")

            # update only provided fields
            if req.owner is not None:
                garment.owner = req.owner
            if req.category is not None:
                garment.category = req.category
            if req.material is not None:
                garment.material = req.material
            if req.color is not None:
                garment.color = req.color
            if req.name is not None:
                garment.name = req.name
            if req.image_url is not None:
                garment.image_url = req.image_url
            if req.dirty is not None:
                garment.dirty = req.dirty

            persisted = store.update(garment)

            return GarmentResponse(
                id=persisted.id,
                owner=persisted.owner,
                category=persisted.category,
                material=persisted.material,
                color=persisted.color,
                name=persisted.name,
                image_url=persisted.image_url,
                dirty=persisted.dirty,
                created_at=persisted.created_at,
            )
    def list_by_owner(self, owner: int) -> ListByOwnerResponse:
        with session_scope(self._session_factory) as s:
            store = MakeGarmentStore(s)
            garments = store.list_by_owner(owner)

            out = [
                GarmentResponse(
                    id=g.id,
                    owner=g.owner,
                    category=g.category,
                    material=g.material,
                    color=g.color,
                    name=g.name,
                    image_url=g.image_url,
                    dirty=g.dirty,
                    created_at=g.created_at,
                )
                for g in garments
            ]
            return ListByOwnerResponse(garments=out)
