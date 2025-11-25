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
    # optional conversation state previously returned by the service
    previous_messages: Optional[List[Dict[str, Any]]] = None


class GenerateOutfitResponse(BaseModel):
    # Indicates what this response contains. Examples: "tool_request" or "garments".
    response_type: str

    # When the agent finished, the selected garments will be provided here.
    garments: Optional[List[GarmentResponse]] = None

    # When the service needs the frontend to perform an action (e.g. collect location),
    # it will return the conversation state here so the frontend can update it and
    # POST it back with the next request.
    previous_messages: Optional[List[Dict[str, Any]]] = None


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


class AvatarUploadResponse(BaseModel):
    avatar_url: str


class TryOnImageRequest(BaseModel):
    """Separate request schema for the try-on preview endpoint.

    This intentionally does not reuse other try-on request types to keep a
    distinct API contract per your instruction.
    """
    garments: List[int]


class TryOnImageResponse(BaseModel):
    """Optional metadata for the try-on preview endpoint responses.

    Note: the endpoint will return raw `image/png` bytes in the response body;
    this model exists separately in case a JSON wrapper is desired elsewhere.
    """
    info: Optional[str] = None

