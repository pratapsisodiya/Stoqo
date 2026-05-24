from sqlalchemy import or_, select

from app.models.user import User
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    model = User

    async def get_by_login(self, login: str) -> User | None:
        result = await self.db.execute(
            select(User).where(or_(User.email == login, User.phone == login))
        )
        return result.scalar_one_or_none()
