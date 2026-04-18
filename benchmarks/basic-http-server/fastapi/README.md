# dart_edge_benchmark_fastapi

FastAPI benchmark target used for Dart Edge comparisons.

This target is served by `uvicorn` and expects its Python dependencies in a
local virtualenv or the active Python environment.

Set up the local environment with:

```sh
cd benchmarks/basic-http-server/fastapi
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Run it directly with:

```sh
.venv/bin/python -m uvicorn server:app --host 127.0.0.1 --port 8080 --workers 1
```

For the full benchmark workflow, see [../README.md](../README.md).
