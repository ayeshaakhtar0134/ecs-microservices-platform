const { SQSClient, SendMessageCommand } = require("@aws-sdk/client-sqs");
const { randomUUID } = require("node:crypto");

// In AWS: publish to SQS so jobs survive worker restarts and spikes.
// Locally (no QUEUE_URL): call the worker over HTTP so docker compose still works.
function createJobSender({ queueUrl = process.env.QUEUE_URL, workerUrl = process.env.WORKER_URL, sqs } = {}) {
  if (queueUrl) {
    const client = sqs || new SQSClient({});
    return async (payload) => {
      const jobId = randomUUID();
      await client.send(
        new SendMessageCommand({
          QueueUrl: queueUrl,
          MessageBody: JSON.stringify({ jobId, payload }),
        })
      );
      return { status: 202, body: { job_id: jobId, status: "queued" } };
    };
  }

  const url = workerUrl || "http://localhost:8000";
  return async (payload) => {
    const r = await fetch(`${url}/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
    return { status: r.status, body: await r.json() };
  };
}

module.exports = { createJobSender };
