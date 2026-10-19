const { createApp } = require("./app");

const port = process.env.PORT || 3000;
const server = createApp().listen(port, () => console.log(`api listening on ${port}`));

// ECS sends SIGTERM before stopping a task; finish in-flight requests
process.on("SIGTERM", () => server.close(() => process.exit(0)));
