from typing import List
from anthropic import Anthropic
from dotenv import load_dotenv
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
        kwargs = {
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1000,
            "messages": messages,
            "system": "You are a fashion expert tasked with providing expert fashion advice"
        }

        response = self.client.messages.create(**kwargs)

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
