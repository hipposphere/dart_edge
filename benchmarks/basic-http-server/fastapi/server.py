from fastapi import Body, FastAPI
from fastapi.responses import PlainTextResponse


BENCHMARK_PLAINTEXT_BODY = "Hello, World!"
BENCHMARK_JSON_PAYLOAD = {"message": "Hello, World!"}
BENCHMARK_ECHO_PAYLOAD = {
    "message": "Echo payload",
    "count": 1,
    "enabled": True,
}

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)


@app.get("/plaintext")
async def plaintext() -> PlainTextResponse:
    return PlainTextResponse(BENCHMARK_PLAINTEXT_BODY)


@app.get("/json")
async def json() -> dict[str, object]:
    return BENCHMARK_JSON_PAYLOAD


@app.get("/users/{user_id}")
async def user(user_id: str) -> dict[str, object]:
    return {"id": user_id, "name": "Benchmark User"}


@app.post("/echo")
async def echo(payload: dict[str, object] | None = Body(default=None)) -> dict[str, object]:
    return payload or BENCHMARK_ECHO_PAYLOAD
