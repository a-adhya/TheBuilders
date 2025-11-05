import pytest
from unittest.mock import MagicMock, patch

from services.chat_service import ChatService


def test_chat_service_generates_response():
    with patch("services.chat_service.Anthropic") as mock_anthropic:
        mock_client = MagicMock()
        mock_response = MagicMock()
        content_item = MagicMock()
        content_item.text = "Test response"
        mock_response.content = [content_item]
        mock_client.messages.create.return_value = mock_response
        mock_anthropic.return_value = mock_client

        service = ChatService()
        result = service.generate_response(
            messages=[{"role": "user", "content": "Test message"}])

        assert result == "Test response"
        mock_client.messages.create.assert_called_once()
