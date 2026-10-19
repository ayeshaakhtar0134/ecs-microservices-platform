import uuid

from fastapi import FastAPI

app = FastAPI(title="worker")


@app.get("/health")
def health():
    return {"status": "ok", "service": "worker"}


@app.post("/jobs")
def create_job(payload: dict):
    # Real work (S3, SQS, DB) would go here using the ECS task role
    return {"job_id": str(uuid.uuid4()), "status": "queued", "input": payload}
