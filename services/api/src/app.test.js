const { test } = require("node:test");
const assert = require("node:assert");
const { createApp } = require("./app");
const { createJobSender } = require("./jobs");

async function withServer(app, fn) {
  const server = app.listen(0);
  try {
    await fn(`http://127.0.0.1:${server.address().port}`);
  } finally {
    server.close();
  }
}

test("GET /health returns ok", async () => {
  await withServer(createApp({ sendJob: async () => ({}) }), async (base) => {
    const res = await fetch(`${base}/health`);
    assert.strictEqual(res.status, 200);
    assert.deepStrictEqual(await res.json(), { status: "ok", service: "api" });
  });
});

test("POST /api/jobs returns what the sender returns", async () => {
  const sendJob = async (payload) => ({ status: 202, body: { status: "queued", echo: payload } });
  await withServer(createApp({ sendJob }), async (base) => {
    const res = await fetch(`${base}/api/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ task: "resize" }),
    });
    assert.strictEqual(res.status, 202);
    assert.deepStrictEqual(await res.json(), { status: "queued", echo: { task: "resize" } });
  });
});

test("POST /api/jobs returns 502 when the sender fails", async () => {
  const sendJob = async () => {
    throw new Error("boom");
  };
  await withServer(createApp({ sendJob }), async (base) => {
    const res = await fetch(`${base}/api/jobs`, { method: "POST" });
    assert.strictEqual(res.status, 502);
  });
});

test("SQS sender publishes the payload with a job id", async () => {
  const sent = [];
  const sqs = { send: async (cmd) => sent.push(cmd.input) };
  const send = createJobSender({ queueUrl: "https://sqs.example/q", sqs });
  const { status, body } = await send({ task: "resize" });
  assert.strictEqual(status, 202);
  assert.strictEqual(sent.length, 1);
  assert.strictEqual(sent[0].QueueUrl, "https://sqs.example/q");
  const message = JSON.parse(sent[0].MessageBody);
  assert.strictEqual(message.jobId, body.job_id);
  assert.deepStrictEqual(message.payload, { task: "resize" });
});
