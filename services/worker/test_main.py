import json

import boto3
import pytest
from fastapi.testclient import TestClient
from moto import mock_aws

from consumer import poll_once
from main import app

client = TestClient(app)


def test_health():
    assert client.get("/health").json() == {"status": "ok", "service": "worker"}


def test_create_job_over_http():
    r = client.post("/jobs", json={"x": 1})
    assert r.status_code == 200
    assert r.json()["status"] == "done"


@pytest.fixture
def queue(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    with mock_aws():
        sqs = boto3.client("sqs", region_name="us-east-1")
        url = sqs.create_queue(QueueName="jobs", Attributes={"VisibilityTimeout": "0"})["QueueUrl"]
        yield sqs, url


def send(sqs, url, payload):
    sqs.send_message(QueueUrl=url, MessageBody=json.dumps({"jobId": "j1", "payload": payload}))


def test_successful_job_is_deleted(queue):
    sqs, url = queue
    send(sqs, url, {"task": "resize"})
    assert poll_once(sqs, url, wait_seconds=0) == (1, 0)
    assert "Messages" not in sqs.receive_message(QueueUrl=url, WaitTimeSeconds=0)


def test_failed_job_stays_for_retry(queue):
    sqs, url = queue
    send(sqs, url, {"fail": True})
    assert poll_once(sqs, url, wait_seconds=0) == (0, 1)
    assert len(sqs.receive_message(QueueUrl=url, WaitTimeSeconds=0)["Messages"]) == 1
