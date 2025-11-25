# TO RUN: PYTHONPATH=src poetry run python -m pytest tests/services/avatar_service_tests.py -q
from contextlib import contextmanager
import io
from PIL import Image
import pytest
from types import SimpleNamespace

from models.enums import Category, Material
import src.services.avatar_service as avatar_module
AvatarService = avatar_module.AvatarService
AvatarGenerationError = avatar_module.AvatarGenerationError

@contextmanager
def fake_session_scope(session_factory):
    yield None


class FakeStore:
    def get(self, id):
        return SimpleNamespace(name="Cool Tee", color="#ffffff", category=Category.SHIRT, material=Material.COTTON)

class FakeMinio:
    def __init__(self):
        self.calls = []
        # simple in-memory object store for get_object
        self.objects = {}
        # optional default data returned by get_object when present
        self.default_get_data = None

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
        # store the object bytes for later retrieval via get_object
        try:
            self.objects[key] = b
        except Exception:
            pass

    def get_object(self, bucket, key):
        """Return a file-like object with the stored bytes for `key`.

        If `default_get_data` is set on the FakeMinio instance, that data
        will be returned regardless of `key`. Otherwise, the last value
        written to `put_object` for that key will be returned.
        """
        data = None
        if self.default_get_data is not None:
            data = self.default_get_data
        else:
            data = self.objects.get(key)

        if data is None:
            raise KeyError(f"object not found: {key}")
        
        buffer = io.BytesIO(data)
        
        return buffer

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
        raise AvatarGenerationError("generation failed")

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

    # Expect a typed error when generation fails; no upload should be attempted
    with pytest.raises(AvatarGenerationError):
        svc.generate_and_upload(7, small_png_bytes)

    assert len(fake_minio.calls) == 0


def test_try_on_uses_enum_names(monkeypatch, small_png_bytes):
    """Ensure `try_on` converts enum/int values to their name strings in the prompt.

    This test reuses the module-level `FakeGenaiClient` and `FakeMinio` and
    wraps/extends them rather than defining new ad-hoc fakes.
    """
    # Reuse the module-level FakeGenaiClient but wrap generate_content to capture
    # the contents passed by AvatarService.
    parts = [Part(inline_data=InlineData(b"ok"))]
    fake_genai = FakeGenaiClient(parts)

    orig_generate = fake_genai.models.generate_content

    def wrapped_generate_content(model, contents):
        fake_genai.last_contents = contents
        return orig_generate(model, contents)

    fake_genai.models.generate_content = wrapped_generate_content
    monkeypatch.setattr(avatar_module, "genai", type("G", (), {"Client": lambda: fake_genai}))

    # Reuse FakeMinio and configure it to return the provided PNG bytes
    fake_minio = FakeMinio()
    fake_minio.default_get_data = small_png_bytes

    # Monkeypatch session_scope and MakeGarmentStore to return a simple garment
    monkeypatch.setattr(avatar_module, "session_scope", fake_session_scope)
    monkeypatch.setattr(avatar_module, "MakeGarmentStore", lambda s: FakeStore())

    svc = AvatarService(session_factory=object(), minio=fake_minio)

    out = svc.try_on(7, [1])

    assert out == b"ok"
    prompt = fake_genai.last_contents[0]
    assert "SHIRT" in prompt
    assert "COTTON" in prompt
