from fastapi import FastAPI, Request, Response
from fastapi.responses import PlainTextResponse


BENCHMARK_PLAINTEXT_BODY = "Hello, World!"
BENCHMARK_JSON_BODY = '{"message":"Hello, World!"}'
BENCHMARK_ECHO_BODY = '{"message":"Echo payload","count":1,"enabled":true}'

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)


@app.get("/plaintext")
async def plaintext() -> PlainTextResponse:
    return PlainTextResponse(BENCHMARK_PLAINTEXT_BODY)


@app.get("/json")
async def json() -> Response:
    return Response(BENCHMARK_JSON_BODY, media_type="application/json")


@app.get("/users/{user_id}")
async def user(user_id: str) -> Response:
    body = f'{{"id":"{user_id}","name":"Benchmark User"}}'
    return Response(body, media_type="application/json")


@app.post("/echo")
async def echo(request: Request) -> Response:
    body = await request.body()
    return Response(body or BENCHMARK_ECHO_BODY.encode(), media_type="application/json")
