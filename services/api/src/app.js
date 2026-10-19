const express = require("express");
const { createJobSender } = require("./jobs");

function createApp({ sendJob = createJobSender() } = {}) {
  const app = express();
  app.use(express.json());

  app.get("/health", (_req, res) => res.json({ status: "ok", service: "api" }));

  app.post("/api/jobs", async (req, res) => {
    try {
      const { status, body } = await sendJob(req.body ?? {});
      res.status(status).json(body);
    } catch (err) {
      console.error(JSON.stringify({ level: "error", msg: "job submit failed", error: err.message }));
      res.status(502).json({ error: "could not submit job" });
    }
  });

  return app;
}

module.exports = { createApp };
