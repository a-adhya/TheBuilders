from types import SimpleNamespace
import pytest

from services.outfit_generator_service import OutfitGeneratorService
from api.schema import GenerateOutfitResponse, GarmentResponse
from models.enums import Category, Material
from datetime import datetime


class FakeContent:
    def __init__(self, type_, name=None, input_=None):
        self.type = type_
        self.name = name
        self.input = input_

    def model_dump(self):
        return {"type": self.type, "name": self.name, "input": self.input}

    def __repr__(self):
        return f"<FakeContent type={self.type} name={self.name} input={self.input}>"


class FakeResponse:
    def __init__(self, contents, id_="resp-id", stop_reason=None):
        # contents: list of FakeContent
        self.content = contents
        self.id = id_
        self.stop_reason = stop_reason


class SequenceFakeClient:
    class MessagesAPI:
        def __init__(self, parent):
            self.parent = parent

        def create(self, model, max_tokens, tools, tool_choice, disable_parallel_tool_use, messages):
            if not self.parent._responses:
                raise RuntimeError("No more fake responses configured")
            return self.parent._responses.pop(0)

    def __init__(self, responses):
        self._responses = list(responses)

    @property
    def messages(self):
        return SequenceFakeClient.MessagesAPI(self)


def make_closet(garment_ids):
    # Create real GarmentResponse objects so Pydantic validation succeeds
    garments = [
        GarmentResponse(
            id=i,
            owner=1,
            category=Category.SHIRT,
            color="#000000",
            name=f"garment-{i}",
            material=Material.COTTON,
            image_url="",
            dirty=False,
            created_at=datetime(2003, 9, 24, 0, 0, 0),
        )
        for i in garment_ids
    ]
    return SimpleNamespace(garments=garments)


def test_previous_messages_provided_returns_garments():
    svc = OutfitGeneratorService()

    # Anthropic responds immediately with final print_outfit_garments tool use
    print_block = FakeContent(
        type_="tool_use", name="print_outfit_garments", input_={"garments": [1, 3]})
    resp = FakeResponse(contents=[print_block], id_="r-final")
    svc.client = SequenceFakeClient([resp])

    closet = make_closet([1, 2, 3, 4])
    # provide previous_messages to simulate frontend resuming
    prev_msgs = [{"role": "assistant", "content": "prev"}]

    out = svc.generate_outfit(closet, context="ctx",
                              previous_messages=prev_msgs)

    assert isinstance(out, GenerateOutfitResponse)
    assert out.response_type == "garments"
    assert out.garments is not None
    returned_ids = [g.id for g in out.garments]
    assert set(returned_ids) == {1, 3}


def test_no_previous_messages_model_requests_location_returns_tool_request():
    svc = OutfitGeneratorService()

    loc_block = FakeContent(type_="tool_use", name="get_location", input_={})
    resp = FakeResponse(contents=[loc_block], id_="r-loc")
    svc.client = SequenceFakeClient([resp])

    closet = make_closet([1, 2, 3])
    out = svc.generate_outfit(closet, context="ctx", previous_messages=None)

    assert isinstance(out, GenerateOutfitResponse)
    assert out.response_type == "tool_request"
    assert out.previous_messages is not None
    # Expect last user entry to contain tool_results placeholder
    user_entries = [
        m for m in out.previous_messages if m.get("role") == "user"]
    assert user_entries, "expected a user entry with tool_results"
    tool_results = user_entries[-1]["content"]
    assert isinstance(tool_results, list)
    assert tool_results[0]["type"] == "tool_result"
    assert tool_results[0]["content"] == "No location provided."


def test_no_previous_messages_model_returns_garments_immediately():
    svc = OutfitGeneratorService()

    print_block = FakeContent(
        type_="tool_use", name="print_outfit_garments", input_={"garments": [2]})
    resp = FakeResponse(contents=[print_block], id_="r-final2")
    svc.client = SequenceFakeClient([resp])

    closet = make_closet([1, 2, 3])
    out = svc.generate_outfit(closet, context="ctx", previous_messages=None)

    assert isinstance(out, GenerateOutfitResponse)
    assert out.response_type == "garments"
    returned_ids = [g.id for g in out.garments]
    assert set(returned_ids) == {2}


def test_weather_then_print_calls_weather_and_returns_garments(monkeypatch):
    svc = OutfitGeneratorService()

    weather_block = FakeContent(type_="tool_use", name="get_weather", input_={
                                "lat": 10.0, "lon": 20.0})
    print_block = FakeContent(
        type_="tool_use", name="print_outfit_garments", input_={"garments": [1, 4]})
    resp1 = FakeResponse(contents=[weather_block], id_="r1")
    resp2 = FakeResponse(contents=[print_block], id_="r2")
    svc.client = SequenceFakeClient([resp1, resp2])

    called = {}

    def fake_weather(lat, lon):
        called['lat'] = lat
        called['lon'] = lon
        return {"summary": "sunny"}

    monkeypatch.setattr(svc, "call_weather_api", fake_weather)

    closet = make_closet([1, 2, 3, 4])
    out = svc.generate_outfit(closet, context="ctx", previous_messages=None)

    assert called.get('lat') == 10.0 and called.get('lon') == 20.0
    assert out.response_type == "garments"
    returned_ids = [g.id for g in out.garments]
    assert set(returned_ids) == {1, 4}
