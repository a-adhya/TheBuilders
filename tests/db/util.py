from datetime import datetime, timezone
import random
import secrets

from db.garmentstore import GarmentType, Garment, MaterialType

def generate_random_garment(owner: int,
                 *,
                 garment_type: GarmentType | None = None,
                 material: MaterialType | None = None,
                 color: str | None = None,
                 name: str | None = None,
                 image_url: str | None = None,
                 created_at: datetime | None = None) -> Garment:
    gt = garment_type or random.choice(list(GarmentType))
    mt = material or random.choice(list(MaterialType))
    nm = name or f"{gt.name.title()}-{secrets.token_hex(3)}"
    clr = color or "#" + "".join(random.choice("0123456789ABCDEF") for _ in range(6))
    img = image_url or f"https://example.test/img/{nm}.jpg"
    ts = created_at or datetime.now(timezone.utc)
    return Garment(
        id=None, owner=owner, type=gt, color=clr, name=nm,
        material=mt, image_url=img, created_at=ts
    )