import test from "node:test";
import assert from "node:assert/strict";
import { createApp } from "../server/app.js";

let server;
let baseUrl;

test.before(async () => {
  const app = await createApp();
  await new Promise((resolve) => {
    server = app.listen(0, "127.0.0.1", resolve);
  });
  const { port } = server.address();
  baseUrl = `http://127.0.0.1:${port}`;
});

test.after(() => {
  server?.close();
});

test("GET /api/health reports ok and a book count", async () => {
  const res = await fetch(`${baseUrl}/api/health`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.status, "ok");
  assert.ok(body.books > 0);
});

test("GET /api/books returns summaries without full chapter text", async () => {
  const res = await fetch(`${baseUrl}/api/books`);
  assert.equal(res.status, 200);
  const books = await res.json();
  assert.ok(Array.isArray(books));
  assert.ok(books.length > 0);
  for (const book of books) {
    assert.ok(book.id && book.title && book.author);
    assert.equal(book.chapters, undefined);
    assert.equal(typeof book.chapterCount, "number");
  }
});

test("GET /api/books?q= filters by query", async () => {
  const res = await fetch(`${baseUrl}/api/books?q=alice`);
  const books = await res.json();
  assert.equal(books.length, 1);
  assert.match(books[0].title, /Alice/);
});

test("GET /api/books?subject= filters by subject", async () => {
  const res = await fetch(`${baseUrl}/api/books?subject=Mystery`);
  const books = await res.json();
  assert.ok(books.length >= 1);
  for (const book of books) {
    assert.ok(book.subjects.includes("Mystery"));
  }
});

test("GET /api/books/:id returns full text", async () => {
  const res = await fetch(`${baseUrl}/api/books/frankenstein`);
  assert.equal(res.status, 200);
  const book = await res.json();
  assert.equal(book.id, "frankenstein");
  assert.ok(Array.isArray(book.chapters));
  assert.ok(book.chapters[0].paragraphs.length > 0);
  assert.ok(book.words > 0);
});

test("GET /api/books/:id returns 404 for unknown id", async () => {
  const res = await fetch(`${baseUrl}/api/books/does-not-exist`);
  assert.equal(res.status, 404);
});

test("GET /api/subjects returns a sorted unique list", async () => {
  const res = await fetch(`${baseUrl}/api/subjects`);
  const subjects = await res.json();
  assert.ok(subjects.length > 0);
  const sorted = [...subjects].sort();
  assert.deepEqual(subjects, sorted);
});
