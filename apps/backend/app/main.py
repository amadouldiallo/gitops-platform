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

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from opentelemetry.instrumentation.utils import suppress_instrumentation
from prometheus_fastapi_instrumentator import Instrumentator

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

# =============================================================================
# Métriques Prometheus — Projet 3 (Observability & SRE Platform)
# =============================================================================
# 🎯 Le concept
# `instrument(app)` ajoute un middleware qui mesure CHAQUE requête HTTP
# (méthode, route, code de statut, durée) ; `expose(app)` publie ces
# mesures sur GET /metrics, au format que Prometheus sait scraper.
#
# ❓ Pourquoi exclure /healthz et /readyz
# Ces deux routes sont sondées par les probes Kubernetes toutes les 5 à 10
# secondes (voir livenessProbe/readinessProbe du chart Helm) — sans les
# exclure, elles domineraient le volume de métriques sans jamais renseigner
# sur l'usage réel de l'API par des utilisateurs.
Instrumentator(excluded_handlers=["/healthz", "/readyz"]).instrument(app).expose(app)

# =============================================================================
# Traces distribuées — Projet 3 (Observability & SRE Platform), Étape 3
# =============================================================================
# 🎯 Le concept
# `FastAPIInstrumentor` crée automatiquement un span par requête HTTP
# entrante ; `PsycopgInstrumentor` fait pareil pour chaque requête SQL —
# et les relie en un seul arbre : une requête `/api/tasks` lente devient
# visible comme "80% du temps passé dans LA requête SQL", pas juste "la
# route est lente" (voir le concept de l'Étape 3 du guide).
#
# ❓ Pourquoi c'est conditionnel (`if OTEL_ENDPOINT`)
# Ce backend appartient au Projet 2 (task-tracker) et doit rester
# utilisable SEUL (`docker compose`, ou un cluster sans le Projet 3) — le
# faire dépendre en dur d'un Tempo qui n'existe pas forcément casserait
# cet usage. Vide par défaut (voir charts/app/values.yaml, rempli
# uniquement par k8s/argocd/application.yaml du Projet 3).
OTEL_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "")
if OTEL_ENDPOINT:
    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    resource = Resource.create({"service.name": os.environ.get("OTEL_SERVICE_NAME", "task-tracker-backend")})
    provider = TracerProvider(resource=resource)
    # insecure=True : le trafic OTLP reste interne au cluster (backend ->
    # Tempo, namespace tracing) — voir k8s/tracing/networkpolicy.yaml
    # (Projet 3) qui restreint déjà QUI peut atteindre Tempo. Chiffrer un
    # saut intra-cluster n'apporterait rien ici.
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True)))
    trace.set_tracer_provider(provider)

    FastAPIInstrumentor.instrument_app(app, excluded_urls="healthz,readyz,metrics")
    PsycopgInstrumentor().instrument()


@app.get("/healthz")
def healthz():
    """Liveness — ne dépend jamais de la base (voir le docstring du module)."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    """Readiness — échoue si la base n'est pas joignable.

    ⚠️ Piège rencontré pour de vrai (Projet 3, Étape 3) : `/readyz` est
    exclu du traçage HTTP (`excluded_urls`, voir plus haut) mais son
    `SELECT 1` reste tracé par `PsycopgInstrumentor` — sans contexte HTTP
    parent puisque la route est exclue, chaque appel (toutes les 5s, voir
    `readinessProbe` du chart Helm) créait une trace À PART ENTIÈRE,
    orpheline, plutôt qu'un span enfant. Découvert en cherchant "pourquoi
    la moitié des traces dans Tempo ne contiennent qu'un SELECT isolé" —
    `suppress_instrumentation()` désactive explicitement toute
    instrumentation (pas seulement HTTP) le temps de cet appel précis.
    """
    try:
        with suppress_instrumentation(), db.pool.connection(timeout=2) as conn:
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
