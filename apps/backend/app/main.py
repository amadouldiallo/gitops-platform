"""
Backend API — le tiers "administration" de la maquette 3-tiers.

🎯 Le concept
Une API REST minimale (FastAPI) qui expose une liste de tâches, stockée
dans PostgreSQL. Le frontend statique ne parle JAMAIS directement à la
base de données : il passe systématiquement par cette API — c'est cette
frontière qui, plus tard (Étape 4 du guide), justifie une NetworkPolicy
bloquant frontend→postgresql en direct.

🧠 Analogie
Voir l'analogie de la "maquette de ville" du guide : ce service est
l'administration — le seul autorisé à consulter/modifier les archives
(la base de données), le frontend (vitrine) doit passer par son guichet.

Deux endpoints de santé DISTINCTS, pas un seul — un choix qui compte dès
qu'on écrit les probes Kubernetes (Étape 3/4) :
  - /healthz : "le process est vivant ?" — ne touche jamais la base.
    C'est la LIVENESS probe : si elle échoue, Kubernetes TUE le pod et le
    redémarre. Elle doit rester vraie même si la base est temporairement
    injoignable — sinon un redémarrage en boucle n'arrangerait rien.
  - /readyz : "le service peut-il RÉPONDRE correctement maintenant ?" —
    vérifie la connexion à la base. C'est la READINESS probe : si elle
    échoue, Kubernetes retire juste le pod de la liste des endpoints
    (aucun trafic ne lui est envoyé), SANS le redémarrer — le bon
    comportement le temps qu'une base momentanément indisponible revienne.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from . import db
from .schemas import Task, TaskCreate


@asynccontextmanager
async def lifespan(app: FastAPI):
    db.pool.open(wait=True, timeout=30)  # attend que Postgres soit joignable au démarrage
    db.ensure_schema()
    yield
    db.pool.close()


app = FastAPI(title="Task Tracker API", lifespan=lifespan)

# CORS ouvert : acceptable ici car le frontend est statique et servi
# séparément (pas de cookies de session à protéger). À restreindre à
# l'origine exacte du frontend si l'appli gagne un jour une authentification.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["*"],
)


@app.get("/healthz")
def healthz():
    """Liveness — ne dépend jamais de la base (voir le docstring du module)."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    """Readiness — échoue si la base n'est pas joignable."""
    try:
        with db.pool.connection(timeout=2) as conn:
            conn.execute("SELECT 1")
    except Exception as exc:  # noqa: BLE001 — on veut juste signaler "pas prêt", peu importe la cause exacte
        raise HTTPException(status_code=503, detail=f"base injoignable : {exc}") from exc
    return {"status": "ready"}


@app.get("/api/tasks", response_model=list[Task])
def list_tasks():
    with db.pool.connection() as conn:
        rows = conn.execute("SELECT id, title, done FROM tasks ORDER BY id").fetchall()
    return [Task(id=r[0], title=r[1], done=r[2]) for r in rows]


@app.post("/api/tasks", response_model=Task, status_code=201)
def create_task(task: TaskCreate):
    with db.pool.connection() as conn:
        row = conn.execute(
            "INSERT INTO tasks (title) VALUES (%s) RETURNING id, title, done",
            (task.title,),
        ).fetchone()
    return Task(id=row[0], title=row[1], done=row[2])


@app.delete("/api/tasks/{task_id}", status_code=204)
def delete_task(task_id: int):
    with db.pool.connection() as conn:
        result = conn.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="tâche introuvable")
