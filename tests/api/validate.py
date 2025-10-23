
from fastapi import HTTPException
import pytest

from api.schema import CreateGarmentRequest
from api.validate import validate_create_garment_request


def base_req():
    return {
        "owner": 1,
        "category": 1,
        "color": "#123ABC",
        "name": "Valid Shirt",
        "material": 1,
        "image_url": "/img/x.png",
        "dirty": False,
    }


def test_validate_accepts_valid_req():
    req = CreateGarmentRequest(**base_req())
    validate_create_garment_request(req)


@pytest.mark.parametrize("bad_color", ["000000", "#GGGGGG", "#1234", "#12"])
def test_validate_rejects_bad_color(bad_color):
    p = base_req()
    p["color"] = bad_color
    req = CreateGarmentRequest(**p)
    with pytest.raises(HTTPException):
        validate_create_garment_request(req)