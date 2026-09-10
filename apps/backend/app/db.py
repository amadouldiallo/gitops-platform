"""
Connexion PostgreSQL — un pool, pas une connexion par requête.

🎯 Le concept
Ouvrir une connexion TCP + authentifier auprès de Postgres a un coût non
négligeable (dizaines de ms). Un pool de connexions les garde ouvertes et
les réutilise entre requêtes HTTP, au lieu d'ouvrir/fermer une connexion à
chaque appel API.

🧠 Analogie
Une connexion par requête, c'est appeler un taxi à chaque trajet. Un pool,
c'est une flotte de voitures de service déjà garées devant le bureau : on
en prend une disponible, on la ramène, prêt pour le suivant — pas besoin
de renégocier un taxi à chaque fois.

❓ Pourquoi c'est important ici
Cette appli tournera un jour derrière plusieurs replicas Kubernetes (voir
le Helm chart, Étape 3). Sans pool, chaque pod ouvrirait/fermerait des
connexions en permanence, ce qui sature vite `max_connections` côté
Postgres bien avant de saturer le CPU applicatif.

Configuration via variables d'environnement (jamais de mot de passe en
dur dans le code) — voir docker-compose.yml pour les valeurs locales, et
la future intégration Vault / External Secrets Operator (Étape 7) pour la
production sur Kubernetes.
"""

import os

from psycopg_pool import ConnectionPool

PGHOST = os.environ.get("PGHOST", "localhost")
PGPORT = os.environ.get("PGPORT", "5432")
PGDATABASE = os.environ.get("PGDATABASE", "appdb")
PGUSER = os.environ.get("PGUSER", "appuser")
PGPASSWORD = os.environ.get("PGPASSWORD", "")

CONNINFO = f"host={PGHOST} port={PGPORT} dbname={PGDATABASE} user={PGUSER} password={PGPASSWORD}"

# open=False : le pool ne se connecte pas au chargement du module (utile au
# démarrage du conteneur si Postgres n'est pas encore prêt) — voir main.py,
# l'événement "startup" appelle pool.open() puis attend explicitly readiness.
pool = ConnectionPool(conninfo=CONNINFO, min_size=1, max_size=5, open=False)


def ensure_schema() -> None:
    """
    Crée la table si elle n'existe pas encore.

    ⚠️ Piège — en production, la gestion de schéma (migrations) devrait
    être un processus explicite et versionné (ex. Alembic, Flyway), pas un
    "CREATE TABLE IF NOT EXISTS" au démarrage de l'appli : deux replicas
    qui démarrent en même temps pourraient créer une race condition, et
    rien ici ne gère les évolutions de schéma (ajouter une colonne, etc.).
    Ce raccourci reste acceptable pour une appli de démonstration dont le
    but est d'illustrer l'architecture 3-tiers, pas la gestion de migration.
    apps/db/init.sql fait déjà ce travail proprement pour Postgres — cette
    fonction est un filet de sécurité si l'appli pointe un jour vers une
    base qui n'a pas été initialisée avec ce script (ex. Cloud SQL).
    """
    with pool.connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id         SERIAL PRIMARY KEY,
                title      TEXT NOT NULL,
                done       BOOLEAN NOT NULL DEFAULT FALSE,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )
