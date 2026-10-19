import logging
import os
import threading
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI

from consumer import process_job, start_consumer

logging.basicConfig(level=logging.INFO, format="%(message)s")


@asynccontextmanager
async def lifespan(_app):
    # In AWS, QUEUE_URL is set and jobs arrive through SQS.
    # Locally it isn't, and the api calls POST /jobs directly.
    stop = threading.Event()
    queue_url = os.environ.get("QUEUE_URL")
    if queue_url:
        start_consumer(queue_url, stop)
    yield
    stop.set()


app = FastAPI(title="worker", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok", "service": "worker"}


@app.post("/jobs")
def create_job(payload: dict):
    return process_job({"jobId": str(uuid.uuid4()), "payload": payload})
