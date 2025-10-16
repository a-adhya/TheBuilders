# db/schema.py
from datetime import datetime
from sqlalchemy import (
    String, Integer, DateTime, func, CheckConstraint, Index
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase): pass

class GarmentRow(Base):
    __tablename__ = "garments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    owner_id: Mapped[int] = mapped_column(Integer, nullable=False) 
    category: Mapped[int] = mapped_column(Integer, nullable=False)
    material: Mapped[int] = mapped_column(Integer, nullable=False)
    color_hex: Mapped[str] = mapped_column(String(7), nullable=False)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    image_url: Mapped[str] = mapped_column(String(512), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        Index("ix_garments_owner_id", "owner_id"),
    )
