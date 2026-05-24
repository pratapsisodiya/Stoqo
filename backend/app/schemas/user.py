import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr

from app.models.user import UserRole


class UserCreate(BaseModel):
    name: str
    email: str | None = None
    phone: str | None = None
    password: str
    role: UserRole = UserRole.staff
    branch_id: uuid.UUID | None = None


class UserUpdate(BaseModel):
    name: str | None = None
    email: str | None = None
    phone: str | None = None
    role: UserRole | None = None
    branch_id: uuid.UUID | None = None
    is_active: bool | None = None


class UserResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    name: str
    email: str | None
    phone: str | None
    role: UserRole
    branch_id: uuid.UUID | None
    is_active: bool
    created_at: datetime
