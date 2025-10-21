from datetime import datetime
from pydantic import BaseModel

from models.enums import Category, Material


class CreateGarmentRequest(BaseModel):
    owner: int
    category: Category
    color: str
    name: str
    material: Material
    image_url: str


class CreateGarmentResponse(CreateGarmentRequest):
    id: int
    created_at: datetime
