# db/schema.py
from datetime import datetime
from sqlalchemy import (
    Enum, String, Integer, DateTime, func, Index
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from models.enums import Category, Material

class Base(DeclarativeBase): pass

class Garment(Base):
    __tablename__ = "garments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    owner: Mapped[int] = mapped_column(Integer, nullable=False) 
    category: Mapped[Category] = mapped_column(Enum(Category), nullable=False)
    material: Mapped[Material] = mapped_column(Enum(Material), nullable=False)
    color: Mapped[str] = mapped_column(String(7), nullable=False)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    image_url: Mapped[str] = mapped_column(String(512), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        Index("ix_garments_owner", "owner"),
    )
