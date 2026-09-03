import { createApp } from "./app.js";

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || "0.0.0.0";

const app = await createApp();

app.listen(PORT, HOST, () => {
  console.log(`Gutenkern is reading at http://${HOST}:${PORT}`);
});
