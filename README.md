# Gutenkern

A lightweight reader for public-domain literature. Gutenkern serves a small,
self-contained library of classic texts (all in the public domain) through a
JSON API and a clean, book-themed web reader.

## Tech stack

- **Runtime:** Node.js (>= 20), ES modules
- **Server:** [Express](https://expressjs.com/) — REST API + static hosting
- **Frontend:** dependency-free HTML/CSS/JS single-page reader
- **Data:** `data/books.json` — bundled catalog with full text (no network needed)
- **Tooling:** ESLint (flat config) + Node's built-in test runner

## Getting started

```bash
npm install       # install dependencies
npm start         # start the server on http://localhost:3000
npm run dev       # start with auto-reload (node --watch)
```

Then open http://localhost:3000 in your browser.

## Scripts

| Command         | Description                              |
| --------------- | ---------------------------------------- |
| `npm start`     | Run the production server                |
| `npm run dev`   | Run with file-watch auto-reload          |
| `npm run lint`  | Lint the codebase with ESLint            |
| `npm test`      | Run the API test suite (`node --test`)   |

## API

| Method & path         | Description                                          |
| --------------------- | ---------------------------------------------------- |
| `GET /api/health`     | Service status and number of books                   |
| `GET /api/subjects`   | Sorted list of available subjects                    |
| `GET /api/books`      | Library summaries; supports `?q=` and `?subject=`    |
| `GET /api/books/:id`  | Full text (chapters + paragraphs) for one book       |

## Project layout

```
data/books.json     bundled public-domain catalog
server/catalog.js   catalog loading + search/query store
server/app.js       Express app factory (used by server + tests)
server/index.js     server entry point
public/             static frontend (index.html, styles.css, app.js)
test/api.test.js    API integration tests
```

## Environment

The repository ships a `.cursor/environment.json` so Cursor Cloud Agents boot
with dependencies installed and the dev server running automatically.
