const grid = document.getElementById("book-grid");
const emptyState = document.getElementById("empty-state");
const resultCount = document.getElementById("result-count");
const searchInput = document.getElementById("search-input");
const subjectSelect = document.getElementById("subject-select");
const libraryView = document.getElementById("library-view");
const readerView = document.getElementById("reader-view");
const reader = document.getElementById("reader");
const backButton = document.getElementById("back-button");

async function api(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`Request failed: ${res.status}`);
  return res.json();
}

function debounce(fn, delay = 200) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

function renderLibrary(books) {
  grid.innerHTML = "";
  resultCount.textContent = `${books.length} ${
    books.length === 1 ? "book" : "books"
  }`;
  emptyState.hidden = books.length !== 0;

  for (const book of books) {
    const card = document.createElement("article");
    card.className = "card";
    card.tabIndex = 0;
    card.setAttribute("role", "button");
    card.innerHTML = `
      <div class="cover" style="background:${book.cover}">
        <h3>${book.title}</h3>
      </div>
      <div class="body">
        <span class="author">${book.author}</span>
        <p class="summary">${book.summary}</p>
        <div class="tags">
          ${book.subjects.map((s) => `<span class="tag">${s}</span>`).join("")}
        </div>
      </div>`;
    const open = () => openBook(book.id);
    card.addEventListener("click", open);
    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        open();
      }
    });
    grid.appendChild(card);
  }
}

async function loadLibrary() {
  const params = new URLSearchParams();
  if (searchInput.value.trim()) params.set("q", searchInput.value.trim());
  if (subjectSelect.value) params.set("subject", subjectSelect.value);
  const books = await api(`/api/books?${params.toString()}`);
  renderLibrary(books);
}

async function openBook(id) {
  const book = await api(`/api/books/${id}`);
  reader.innerHTML = `
    <h2 class="book-title">${book.title}</h2>
    <p class="book-author">${book.author}</p>
    <p class="book-meta">${book.year} · ${book.words.toLocaleString()} words · ${book.subjects.join(
    ", "
  )}</p>
    ${book.chapters
      .map(
        (chapter) => `
      <h3 class="chapter-title">${chapter.title}</h3>
      ${chapter.paragraphs.map((p) => `<p class="text">${p}</p>`).join("")}`
      )
      .join("")}`;
  libraryView.hidden = true;
  readerView.hidden = false;
  window.scrollTo({ top: 0, behavior: "smooth" });
  history.replaceState({ book: id }, "", `#${id}`);
}

function showLibrary() {
  readerView.hidden = true;
  libraryView.hidden = false;
  history.replaceState({}, "", "#");
}

async function loadSubjects() {
  const subjects = await api("/api/subjects");
  for (const subject of subjects) {
    const option = document.createElement("option");
    option.value = subject;
    option.textContent = subject;
    subjectSelect.appendChild(option);
  }
}

backButton.addEventListener("click", showLibrary);
searchInput.addEventListener("input", debounce(loadLibrary));
subjectSelect.addEventListener("change", loadLibrary);

async function init() {
  try {
    await loadSubjects();
    await loadLibrary();
    const hash = window.location.hash.slice(1);
    if (hash) await openBook(hash);
  } catch (err) {
    grid.innerHTML = `<p class="empty">Could not load the library: ${err.message}</p>`;
  }
}

init();
