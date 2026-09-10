"""Modèles Pydantic — la forme des données qui entrent et sortent de l'API.

FastAPI s'en sert pour valider automatiquement les requêtes (une requête
POST /api/tasks sans "title" est rejetée AVANT d'atteindre notre code) et
pour générer la documentation OpenAPI interactive sur /docs.
"""

from pydantic import BaseModel, Field


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)


class Task(BaseModel):
    id: int
    title: str
    done: bool
