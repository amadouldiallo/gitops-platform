# =============================================================================
# Backend — build multi-stage, utilisateur non-root, image minimale
# =============================================================================
#
# 🎯 Le concept
# Deux étapes (stages) dans ce fichier : "builder" installe les dépendances
# Python (qui ont parfois besoin d'outils de compilation), "runtime" ne
# récupère QUE les paquets déjà installés, jamais les outils qui ont servi
# à les construire.
#
# 🧠 Analogie
# Le multi-stage build, c'est ne servir au client que l'assiette finale —
# pas toute la cuisine (compilateurs, outils de build) qui a servi à
# préparer le plat. Le client (l'image finale poussée en registre) n'a
# jamais vu la cuisine.
#
# ❓ Pourquoi c'est important
# Moins de binaires dans l'image finale = moins de surface de
# vulnérabilités (rien à patcher si ce n'est pas présent) et une image
# plus légère = pull plus rapide, moins de stockage facturé sur le
# registre (encore un réflexe FinOps).

# --- Stage 1 : builder ------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /build

# --no-cache-dir : pas de cache pip dans l'image (celui-ci ne sert à rien
# une fois l'image construite, juste du poids mort).
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- Stage 2 : runtime -------------------------------------------------------
FROM python:3.12-slim AS runtime

# ⚠️ Piège — par défaut, un conteneur Docker tourne en root. Si l'appli est
# compromise (ex. faille dans une dépendance), un attaquant hérite des
# droits root À L'INTÉRIEUR du conteneur — un premier pas vers une
# évasion de conteneur. Un utilisateur dédié, non privilégié, limite ce
# que l'attaquant peut faire même en cas de compromission complète de
# l'appli.
RUN useradd --create-home --uid 10001 --shell /usr/sbin/nologin appuser

# Copie UNIQUEMENT les paquets déjà installés du stage builder — jamais
# les outils de compilation qui ont servi à les construire.
COPY --from=builder /install /usr/local

WORKDIR /app
COPY app/ ./app/

# Étape 4 (socle de sécurité) déploie ce conteneur avec
# readOnlyRootFilesystem: true — Python écrirait normalement des fichiers
# .pyc de cache bytecode à côté des .py au premier import, ce qui
# échouerait silencieusement (pas de crash, juste un cache jamais créé) et
# ralentirait imperceptiblement le démarrage. Autant lui dire explicitement
# de ne pas essayer.
ENV PYTHONDONTWRITEBYTECODE=1

USER appuser

EXPOSE 8000

# HEALTHCHECK : indépendant des probes Kubernetes (Étape 3/4) — utile dès
# maintenant pour `docker compose` / `docker run` en local, avant même
# d'avoir un cluster. Interroge /healthz (liveness, pas de dépendance DB —
# voir app/main.py), pas /readyz. 127.0.0.1 plutôt que "localhost" : évite
# le même piège de résolution IPv6-d'abord que sur l'image frontend (voir
# son Dockerfile), même si l'image Debian de ce backend n'est pas
# affectée aujourd'hui — cohérence entre les deux images plutôt que de
# dépendre d'un comportement de résolution DNS qui diffère entre glibc et
# musl.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2).status == 200 else 1)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
