import random
import secrets

from db.schema import Garment
from models.enums import Category, Material


def generate_random_garment(
    owner: int,
    category: Category | None = None,
    material: Material | None = None,
    color: str | None = None,
    name: str | None = None,
    image_url: str | None = None,
) -> Garment:
    ct = category or random.choice(list(Category))
    mt = material or random.choice(list(Material))
    nm = name or f"{ct.name.title()}-{secrets.token_hex(3)}"
    clr = color or "#" + "".join(random.choice("0123456789ABCDEF") for _ in range(6))
    img = image_url or f"https://example.test/img/{nm}.jpg"
    return Garment(
        owner=owner, category=ct, color=clr, name=nm, material=mt, image_url=img, dirty=False
    )
