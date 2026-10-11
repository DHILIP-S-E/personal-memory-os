from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.auth import get_current_user_id
from app.config import settings
from app.routers import reminders, events, captures, memory, ai, account, devices, auth, notifications, dashboard

@asynccontextmanager
async def lifespan(_app: FastAPI):
    if settings.auto_create_tables:
        # Local development only. Production schemas come from `alembic upgrade head`.
        import app.models  # noqa: F401  (register every table)
        from app.database import Base, engine

        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    lifespan=lifespan,
    title="Personal Memory OS API",
    version="1.0.0",
    description="AWS-native personal reminder and memory platform",
)

# Auth is a Bearer header (no cookies), so credentials are not needed; that also makes
# a specific origin list safe. Set CORS_ORIGINS to the web app's address in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",") if o.strip()],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(reminders.router, prefix="/reminders", tags=["reminders"])
app.include_router(events.router, prefix="/events", tags=["events"])
app.include_router(captures.router, prefix="/captures", tags=["captures"])
app.include_router(memory.router, prefix="/memory", tags=["memory"])
app.include_router(ai.router, prefix="/ai", tags=["ai"])
app.include_router(account.router, prefix="/account", tags=["account"])
app.include_router(devices.router, prefix="/devices", tags=["devices"])
app.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
app.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "service": "Personal Memory OS API", "version": "1.0.0"}


@app.get("/health/me", tags=["health"])
async def health_me(user_id: str = Depends(get_current_user_id)):
    """Protected health check - returns the authenticated user's ID."""
    return {"status": "ok", "user_id": user_id}
