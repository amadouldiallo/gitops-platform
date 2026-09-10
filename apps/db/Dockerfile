# =============================================================================
# Base de données — conteneurisée pour la démo, PAS pour la production
# =============================================================================
#
# ⚠️ Piège — ce Dockerfile existe pour que "chaque composant soit dans son
# propre dossier, prêt à être conteneurisé" (consigne de l'Étape 1) et pour
# le confort du `docker compose` local (voir docker-compose.yml). Ce n'est
# PAS le pattern recommandé en production Kubernetes : une base de données
# a un état (les données) qui doit survivre au pod qui la sert, ce qui
# demande du stockage persistant, des sauvegardes, du failover — des
# problèmes déjà résolus par un service managé (Cloud SQL sur GCP). Faire
# tourner sa propre base dans un pod Kubernetes ("stateful" workload) reste
# possible (StatefulSet + PersistentVolumeClaim) mais rajoute une charge
# opérationnelle qu'un service managé évite. Ce choix sera reconfirmé — ou
# révisé — à l'Étape 6 (GitOps) une fois le vrai déploiement Kubernetes en
# jeu.
FROM postgres:16-alpine

COPY init.sql /docker-entrypoint-initdb.d/init.sql
