// Frontend "statique" volontairement sans framework ni étape de build : le
// guide (Étape 1) demande explicitement un frontend statique. Un vrai
// multi-stage build Docker (voir apps/backend/Dockerfile) n'a de sens que
// s'il y a quelque chose à COMPILER (TypeScript, bundling...) — ici il n'y
// a rien à compiler, donc l'image Docker (voir Dockerfile de ce dossier)
// se contente de copier ces fichiers tels quels dans nginx.
//
// Chemin d'API relatif ("/api/tasks", jamais une URL absolue type
// "http://backend:8000") : c'est nginx (voir nginx.conf) qui reverse-proxy
// "/api/" vers le service backend. Le navigateur, lui, ne parle qu'à
// l'origine sur laquelle la page a été chargée — "backend" en tant que nom
// DNS n'existerait de toute façon pour lui (c'est un nom interne au réseau
// Docker/Kubernetes, invisible depuis l'extérieur). Ce même chemin relatif
// fonctionnera SANS AUCUN changement une fois derrière l'Ingress de
// l'Étape 5, qui route "/api" vers backend exactement de la même manière.

const API_BASE = "/api/tasks";

const form = document.getElementById("task-form");
const input = document.getElementById("task-title");
const list = document.getElementById("task-list");
const status = document.getElementById("status");

function setStatus(message, isError = false) {
  status.textContent = message;
  status.style.color = isError ? "#b91c1c" : "#4b5563";
}

async function loadTasks() {
  setStatus("Chargement…");
  try {
    const res = await fetch(API_BASE);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const tasks = await res.json();
    renderTasks(tasks);
    setStatus(tasks.length ? "" : "Aucune tâche pour l'instant.");
  } catch (err) {
    setStatus(`Impossible de charger les tâches (${err.message}).`, true);
  }
}

function renderTasks(tasks) {
  list.innerHTML = "";
  for (const task of tasks) {
    const li = document.createElement("li");

    const label = document.createElement("span");
    label.textContent = task.title;

    const del = document.createElement("button");
    del.textContent = "Supprimer";
    del.className = "delete";
    del.addEventListener("click", () => deleteTask(task.id));

    li.append(label, del);
    list.appendChild(li);
  }
}

async function createTask(title) {
  const res = await fetch(API_BASE, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
}

async function deleteTask(id) {
  try {
    const res = await fetch(`${API_BASE}/${id}`, { method: "DELETE" });
    if (!res.ok && res.status !== 404) throw new Error(`HTTP ${res.status}`);
    await loadTasks();
  } catch (err) {
    setStatus(`Suppression impossible (${err.message}).`, true);
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const title = input.value.trim();
  if (!title) return;
  try {
    await createTask(title);
    input.value = "";
    await loadTasks();
  } catch (err) {
    setStatus(`Ajout impossible (${err.message}).`, true);
  }
});

loadTasks();
