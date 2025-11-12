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


def test_chat_service_handles_content_list():
    # Ensure the service accepts messages where `content` is a list of blocks
    with patch("services.chat_service.Anthropic") as mock_anthropic:
        mock_client = MagicMock()
        mock_response = MagicMock()
        content_item = MagicMock()
        content_item.text = "Image described"
        mock_response.content = [content_item]
        mock_client.messages.create.return_value = mock_response
        mock_anthropic.return_value = mock_client

        service = ChatService()
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {"type": "url", "url": "https://example.com/img1.jpg"},
                    },
                    {"type": "text", "text": "How is this outfit?"},
                ],
            },
            {"role": "assistant", "content": "It's great!"},
            {"role": "user", "content": "Are you sure?"},
        ]

        result = service.generate_response(messages=messages)

        assert result == "Image described"
        # ensure the underlying client was called and received a messages parameter
        mock_client.messages.create.assert_called_once()
        called_kwargs = mock_client.messages.create.call_args.kwargs
        assert "messages" in called_kwargs
        # the service should forward the list structure (no crash)
        assert isinstance(called_kwargs["messages"], list)
