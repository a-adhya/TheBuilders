from datetime import datetime
from pydantic import BaseModel
from typing import Optional, List, Dict, Any, Union

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
    image_url: str
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
    # Content is a string containing the message.
    # For a message that includes an image, content is a list of objects
    # with an image and a text block.
    # Example:
    # [
    #   {"type": "image", "source": {"type": "url", "url": "https://..."}},
    #   {"type": "text", "text": "Describe this image."}
    # ]
    content: Union[List[Dict[str, Any]], str]


class ChatRequest(BaseModel):
    # accept a full conversation history (list of prior turns)
    messages: List[ConversationMessage]


class ChatResponse(BaseModel):
    response: str


class DeleteGarmentResponse(GarmentResponse):
    pass
