from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health():
    assert client.get("/health").json() == {"status": "ok", "service": "worker"}


def test_create_job():
    r = client.post("/jobs", json={"x": 1})
    assert r.status_code == 200
    assert r.json()["status"] == "queued"
