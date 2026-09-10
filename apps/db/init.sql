-- Exécuté automatiquement au premier démarrage du conteneur Postgres (image
-- officielle : tout .sql dans /docker-entrypoint-initdb.d/ est joué une
-- seule fois, à la création du volume de données — pas à chaque redémarrage).
--
-- Doublon volontaire avec ensure_schema() dans apps/backend/app/db.py : ce
-- script est la version "propre" (exécutée une fois, par Postgres
-- lui-même) ; la fonction Python est un filet de sécurité si l'appli
-- pointe un jour vers une base qui n'a pas été initialisée avec CE script
-- (ex. une instance Cloud SQL managée). Voir le commentaire de
-- ensure_schema() pour les limites de cette approche (pas de vraies
-- migrations).
CREATE TABLE IF NOT EXISTS tasks (
    id         SERIAL PRIMARY KEY,
    title      TEXT NOT NULL,
    done       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
