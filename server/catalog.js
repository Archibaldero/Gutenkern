import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_PATH = join(__dirname, "..", "data", "books.json");

function wordCount(book) {
  return book.chapters.reduce(
    (total, chapter) =>
      total +
      chapter.paragraphs.reduce(
        (sum, paragraph) => sum + paragraph.trim().split(/\s+/).length,
        0
      ),
    0
  );
}

export async function loadCatalog() {
  const raw = await readFile(DATA_PATH, "utf8");
  const books = JSON.parse(raw);
  return books.map((book) => ({ ...book, words: wordCount(book) }));
}

function toSummary(book) {
  const { chapters, ...rest } = book;
  return { ...rest, chapterCount: book.chapters.length };
}

export function createStore(books) {
  const byId = new Map(books.map((book) => [book.id, book]));

  return {
    all: () => books.map(toSummary),
    search({ q = "", subject = "" } = {}) {
      const query = q.trim().toLowerCase();
      const subjectFilter = subject.trim().toLowerCase();
      return books
        .filter((book) => {
          const haystack =
            `${book.title} ${book.author} ${book.summary}`.toLowerCase();
          const matchesQuery = !query || haystack.includes(query);
          const matchesSubject =
            !subjectFilter ||
            book.subjects.some((s) => s.toLowerCase() === subjectFilter);
          return matchesQuery && matchesSubject;
        })
        .map(toSummary);
    },
    subjects() {
      const set = new Set();
      for (const book of books) {
        for (const subject of book.subjects) set.add(subject);
      }
      return [...set].sort();
    },
    get(id) {
      return byId.get(id) ?? null;
    },
  };
}
