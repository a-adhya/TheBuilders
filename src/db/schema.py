# db/schema.py
from datetime import datetime
from sqlalchemy import Boolean, Enum, String, Integer, DateTime, UniqueConstraint, func, Index, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from models.enums import Category, Material


class Base(DeclarativeBase):
    pass


class Garment(Base):
    __tablename__ = "garments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    owner: Mapped[int] = mapped_column(Integer, nullable=False)
    category: Mapped[Category] = mapped_column(Enum(Category), nullable=False)
    material: Mapped[Material] = mapped_column(Enum(Material), nullable=False)
    color: Mapped[str] = mapped_column(String(7), nullable=False)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    image_url: Mapped[str] = mapped_column(String(512), nullable=False)
    dirty: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=text("0")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (Index("ix_garments_owner", "owner"),)

class User(Base):
    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("username", name="uq_users_username"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(150), nullable=False, index=True, unique=True)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )