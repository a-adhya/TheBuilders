from datetime import datetime
from pydantic import BaseModel
from typing import Optional, List

from models.enums import Category, Material


class GarmentResponse(BaseModel):
    id: int
    owner: int
    category: Category
    color: str
    name: str
    material: Material
    image_url: str
    dirty: bool
    created_at: datetime


class CreateGarmentRequest(BaseModel):
    owner: int
    category: Category
    color: str
    name: str
    material: Material
    dirty: bool


class CreateGarmentResponse(GarmentResponse):
    pass


class ListByOwnerResponse(BaseModel):
    garments: List[GarmentResponse]


class UpdateGarmentRequest(BaseModel):
    owner: Optional[int] = None
    category: Optional[Category] = None
    color: Optional[str] = None
    name: Optional[str] = None
    material: Optional[Material] = None
    image_url: Optional[str] = None
    dirty: Optional[bool] = None


class GenerateOutfitRequest(BaseModel):
    optional_string: Optional[str] = None


class GenerateOutfitResponse(BaseModel):
    garments: list[GarmentResponse]


class ConversationMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    # accept a full conversation history (list of prior turns)
    messages: List[ConversationMessage]


class ChatResponse(BaseModel):
    response: str


class DeleteGarmentResponse(GarmentResponse):
    pass
