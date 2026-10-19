const express = require("express");

const WORKER_URL = process.env.WORKER_URL || "http://localhost:8000";

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => res.json({ status: "ok", service: "api" }));

// Calls the worker service over Cloud Map DNS (worker.dev.internal)
app.post("/api/jobs", async (req, res) => {
  try {
    const r = await fetch(`${WORKER_URL}/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(req.body ?? {}),
    });
    res.status(r.status).json(await r.json());
  } catch (err) {
    res.status(502).json({ error: "worker unavailable", detail: err.message });
  }
});

module.exports = app;
