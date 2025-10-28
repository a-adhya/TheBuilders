from datetime import datetime
from pydantic import BaseModel
from typing import Optional

from models.enums import Category, Material


class CreateGarmentRequest(BaseModel):
    owner: int
    category: Category
    color: str
    name: str
    material: Material
    image_url: str
    dirty: bool


class CreateGarmentResponse(CreateGarmentRequest):
    id: int
    created_at: datetime


class UpdateGarmentRequest(BaseModel):
    owner: Optional[int] = None
    category: Optional[Category] = None
    color: Optional[str] = None
    name: Optional[str] = None
    material: Optional[Material] = None
    image_url: Optional[str] = None
    dirty: Optional[bool] = None
