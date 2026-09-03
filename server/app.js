import express from "express";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { loadCatalog, createStore } from "./catalog.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = join(__dirname, "..", "public");

export async function createApp() {
  const books = await loadCatalog();
  const store = createStore(books);
  const app = express();

  app.get("/api/health", (_req, res) => {
    res.json({ status: "ok", books: books.length });
  });

  app.get("/api/subjects", (_req, res) => {
    res.json(store.subjects());
  });

  app.get("/api/books", (req, res) => {
    const { q, subject } = req.query;
    res.json(store.search({ q, subject }));
  });

  app.get("/api/books/:id", (req, res) => {
    const book = store.get(req.params.id);
    if (!book) {
      res.status(404).json({ error: "Book not found" });
      return;
    }
    res.json(book);
  });

  app.use(express.static(PUBLIC_DIR));

  return app;
}
