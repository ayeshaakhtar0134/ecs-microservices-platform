"""Long-polls the jobs queue and processes messages.

A message is deleted only after it is processed successfully. If processing
raises, the message becomes visible again and SQS retries it; after 5 failures
it moves to the dead-letter queue (see infra/queue.tf).
"""
import json
import logging
import threading

import boto3

log = logging.getLogger("worker.consumer")


def process_job(job):
    """The real work goes here (resize an image, call an API, write to S3...)."""
    payload = job.get("payload", {})
    if payload.get("fail"):
        raise ValueError("job asked to fail")  # handy for testing the DLQ
    log.info(json.dumps({"msg": "job processed", "job_id": job.get("jobId")}))
    return {"job_id": job.get("jobId"), "status": "done"}


def poll_once(sqs, queue_url, wait_seconds=20):
    """Receive up to 10 messages, process each, delete the ones that succeed.
    Returns (processed, failed)."""
    resp = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=10, WaitTimeSeconds=wait_seconds)
    processed = failed = 0
    for msg in resp.get("Messages", []):
        try:
            process_job(json.loads(msg["Body"]))
        except Exception:  # noqa: BLE001 - any failure means "retry later"
            failed += 1
            log.exception("job failed, leaving it on the queue for retry")
            continue
        sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=msg["ReceiptHandle"])
        processed += 1
    return processed, failed


def start_consumer(queue_url, stop_event):
    sqs = boto3.client("sqs")

    def run():
        log.info("consumer started")
        while not stop_event.is_set():
            try:
                poll_once(sqs, queue_url)
            except Exception:  # noqa: BLE001 - keep polling through transient AWS errors
                log.exception("poll failed")
                stop_event.wait(5)

    thread = threading.Thread(target=run, name="sqs-consumer", daemon=True)
    thread.start()
    return thread
