"""FastAPI application factory."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from cryptotrace.api.routes import router
from cryptotrace.config import CORS_ORIGINS


def create_app() -> FastAPI:
    app = FastAPI(
        title="CryptoTrace — VASP Attribution Portal",
        description="Heuristic Ethereum wallet-to-VASP attribution service (prototype).",
        version="1.1.0",
    )
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
