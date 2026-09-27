"""FastAPI application factory."""
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from cryptotrace.api.routes import router
from cryptotrace.config import (
    CORS_ORIGINS,
    RATE_LIMIT_REQUESTS_PER_WINDOW,
    RATE_LIMIT_WINDOW_SECONDS,
)
from cryptotrace.services.rate_limit import InMemoryRateLimiter


def create_app() -> FastAPI:
    app = FastAPI(
        title="CryptoTrace — VASP Attribution Portal",
        description="Heuristic Ethereum wallet-to-VASP attribution service (prototype).",
        version="1.1.0",
    )
    rate_limiter = InMemoryRateLimiter(
        RATE_LIMIT_REQUESTS_PER_WINDOW,
        RATE_LIMIT_WINDOW_SECONDS,
    )

    @app.middleware("http")
    async def rate_limit_protected_endpoints(request: Request, call_next):
        path = request.url.path
        protected = path == "/api/trace" or path.startswith("/api/report/") or path.startswith("/api/case/")
        if protected:
            client_host = request.client.host if request.client else "unknown"
            bucket = path.split("/", 3)[2] if path.startswith("/api/") else path
            allowed, retry_after = rate_limiter.allow(f"{client_host}:{bucket}")
            if not allowed:
                return JSONResponse(
                    status_code=429,
                    content={
                        "detail": "Rate limit exceeded. Please retry later.",
                        "retry_after_seconds": retry_after,
                    },
                    headers={"Retry-After": str(retry_after)},
                )
        return await call_next(request)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )
    app.include_router(router)
    return app


app = create_app()
