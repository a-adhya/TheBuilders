from typing import List
from anthropic import Anthropic
from dotenv import load_dotenv
import base64
import httpx
import os


class ChatService:
    """Simple wrapper around the Anthropic client for chat responses.

    Uses the same API_KEY env var as the outfit generator service.
    """

    def __init__(self):
        load_dotenv()
        api_key = os.getenv("API_KEY")
        self.client = Anthropic(api_key=api_key)

    def generate_response(self, messages: list) -> str:
        """Send a conversation history (messages) to Anthropic with our fashion expert system prompt.

        messages: list of objects like {"role": "user"|"assistant", "content": str}.
        Returns concatenated text blocks from the assistant response.
        """

        for msg in messages:
            if msg.get("role") == "user" and isinstance(msg.get("content"), list):
                for item in msg["content"]:
                    if isinstance(item, dict) and item.get("type") == "image":
                        src = item.get("source") or {}
                        if src.get("type") == "base64":
                            continue  # already have base64 data
                        image_url = src.get("url")
                        if not image_url:
                            continue  # nothing to fetch
                        image_media_type = "image/jpeg"
                        image_data = base64.standard_b64encode(
                            httpx.get(image_url).content).decode("utf-8")
                        item["source"] = {
                            "type": "base64",
                            "media_type": image_media_type,
                            "data": image_data,
                        }

        kwargs = {
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1000,
            "messages": messages,
            "system": "You are a fashion expert tasked with providing expert fashion advice"
        }

        try:
            response = self.client.messages.create(**kwargs)
        except Exception as e:
            raise Exception("Error: Anthropic API error") from e

        # Collect text pieces from the response content
        pieces: List[str] = []
        for content in response.content:
            # content objects in this client usually expose `.text`
            if getattr(content, "type", None) == "text":
                text = getattr(content, "text", None)
                if text:
                    pieces.append(text)
            else:
                # Fallback: if there's a text attribute, include it
                if hasattr(content, "text") and content.text:
                    pieces.append(content.text)

        result = "".join(pieces).strip()
        if result:
            return result
        else:
            raise Exception("Error: no text returned from Anthropic")
