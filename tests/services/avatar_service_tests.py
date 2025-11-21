# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/services/avatar_service_tests.py -q
import io
from PIL import Image
import pytest

import src.services.avatar_service as avatar_module
from services.avatar_service import AvatarService


class FakeMinio:
    def __init__(self):
        self.calls = []

    def put_object(self, bucket, key, data, length=None, content_type=None):
        # read bytes from file-like if provided
        if hasattr(data, "read"):
            data.seek(0)
            b = data.read()
        else:
            b = data
        self.calls.append({
            "bucket": bucket,
            "key": key,
            "data": b,
            "length": length,
            "content_type": content_type,
        })

# Client for successful tests
class FakeGenaiClient:
    def __init__(self, parts):
        class Models:
            def __init__(self, parts):
                self._parts = parts

            def generate_content(self, model, contents):
                class Resp:
                    def __init__(self, parts):
                        self.parts = parts

                return Resp(self._parts)

        self.models = Models(parts)
        
class InlineData:
    def __init__(self, data: bytes):
        self.data = data


class Part:
    def __init__(self, inline_data=None):
        self.inline_data = inline_data

# Client for bad tests      
class BadModels:
    def generate_content(self, model, contents):
        raise RuntimeError("generation failed")

class BadClient:
    def __init__(self):
        self.models = BadModels()


@pytest.fixture
def small_png_bytes():
    img = Image.new("RGBA", (8, 8), (255, 0, 0, 255))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_generate_and_upload_success(monkeypatch, small_png_bytes):
    # Arrange
    generated_bytes = b"generated-by-genai"
    parts = [Part(inline_data=InlineData(generated_bytes))]
    fake_genai = FakeGenaiClient(parts)

    # patch the genai.Client used in avatar_module
    monkeypatch.setattr(avatar_module, "genai", type("G", (), {"Client": lambda: fake_genai}))

    fake_minio = FakeMinio()
    svc = AvatarService(session_factory=None, minio=fake_minio)

    # Act
    avatar_path = svc.generate_and_upload(123, small_png_bytes)

    # Assert
    assert avatar_path == "/avatars/user_123"
    assert len(fake_minio.calls) == 1
    call = fake_minio.calls[0]
    assert call["bucket"] == "avatars"
    assert call["key"] == "user_123"
    assert call["content_type"] == "image/png"
    assert call["length"] == len(call["data"]) 


def test_generate_and_upload_fail(monkeypatch, small_png_bytes):
    # Arrange: genai client that raises on generate_content
    monkeypatch.setattr(avatar_module, "genai", type("G", (), {"Client": lambda: BadClient()}))

    fake_minio = FakeMinio()
    svc = AvatarService(session_factory=None, minio=fake_minio)
    avatar_path = svc.generate_and_upload(7, small_png_bytes)

    # Assert - since genai errored, original bytes should be uploaded
    assert avatar_path == "/avatars/user_7"
    assert len(fake_minio.calls) == 1
    call = fake_minio.calls[0]
    assert call["key"] == "user_7"
    assert call["bucket"] == "avatars"
    assert call["content_type"] == "image/png"
