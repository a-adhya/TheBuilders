import re

from fastapi import HTTPException

from api.schema import CreateGarmentRequest

HEX_COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")


def _validate_color(value: str) -> None:
    if not isinstance(value, str) or not HEX_COLOR_RE.fullmatch(value):
        raise HTTPException(
            status_code=400, detail="invalid color hex code (expected #RRGGBB or #RGB)"
        )


def validate_create_garment_request(req: CreateGarmentRequest) -> None:
    # make sure hex code is valid
    _validate_color(req.color)
    # other validations...
