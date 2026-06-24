# My FastAPI App

A basic FastAPI project.

## Setup

1. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Running

Start the development server:
```bash
fastapi dev main.py
```

Or with Uvicorn directly:
```bash
uvicorn main:app --reload
```

The API will be available at `http://127.0.0.1:8000`.

Interactive API docs (Swagger UI) are at `http://127.0.0.1:8000/docs`.
