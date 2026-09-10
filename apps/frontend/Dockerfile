# =============================================================================
# Frontend — pas de multi-stage ici, et c'est volontaire
# =============================================================================
#
# ❓ Pourquoi PAS de multi-stage build, contrairement au backend
# Le multi-stage n'apporte de valeur que s'il y a quelque chose à COMPILER
# (dépendances de build, transpilation...) qu'on veut exclure de l'image
# finale. Ce frontend est un frontend STATIQUE (HTML/CSS/JS bruts, voir
# app.js) : il n'y a rien à construire, donc rien à exclure. Ajouter un
# stage ici n'apporterait aucun bénéfice, juste de la complexité gratuite —
# le même principe de moindre privilège s'applique aussi à la complexité
# du Dockerfile lui-même : ne pas en ajouter sans raison concrète.
#
# nginxinc/nginx-unprivileged plutôt que l'image nginx officielle : conçue
# pour tourner nativement en non-root (écoute sur le port 8080, pas 80 —
# les ports <1024 sont réservés à root sous Linux), donc pas besoin de
# bricoler un utilisateur/permissions à la main pour obtenir la même
# garantie de sécurité que le backend (voir son Dockerfile).
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Un TEMPLATE, pas un fichier de conf statique : l'entrypoint officiel de
# l'image (script 20-envsubst-on-templates.sh, déjà présent dans la base
# nginx) transforme tout fichier /etc/nginx/templates/*.template en
# /etc/nginx/conf.d/*.conf au DÉMARRAGE du conteneur, en substituant les
# variables d'environnement réellement définies dans le conteneur — voir
# nginx.conf.template pour pourquoi (le nom du service backend diffère
# entre docker-compose et Kubernetes, piège rencontré en testant ce chart
# sur un vrai cluster GKE).
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY index.html app.js style.css /usr/share/nginx/html/

# Valeurs par défaut pour `docker compose` (voir docker-compose.yml, le
# service s'y appelle "backend") — le chart Helm les surcharge avec le
# vrai nom du Service Kubernetes (voir charts/app/templates/frontend-deployment.yaml).
ENV BACKEND_HOST=backend
ENV BACKEND_PORT=8000

EXPOSE 8080

# 127.0.0.1, pas "localhost" : sur cette image Alpine (musl), "localhost"
# se résout d'abord en ::1 (IPv6) — sur lequel rien n'écoute puisque nginx
# n'écoute qu'en IPv4 (0.0.0.0:8080, voir nginx.conf) — ce qui fait échouer
# le HEALTHCHECK avec "connection refused" malgré un service qui répond
# parfaitement bien en IPv4. Rencontré et corrigé en testant ce Dockerfile.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
