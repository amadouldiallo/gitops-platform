# Projet 2 — Kubernetes Platform & GitOps
## Guide d'apprentissage pédagogique

**Objectif du projet :** permettre à un développeur de déployer une application sur Kubernetes uniquement via Git, avec un socle de sécurité et une gestion des secrets propre.

Ce guide suit 8 étapes. Pour chacune : le concept en langage simple, une analogie, pourquoi c'est important, et un prompt Claude Code pour le construire. S'appuie sur le cluster GKE du [Projet 1](../cloud-platform/Projet-1-Cloud-Terraform-Guide.md).

---

## Étape 1 — Application de démonstration

**🎯 Le concept**
Construire une petite appli 3-tiers (frontend, backend, PostgreSQL) pour avoir un cas d'usage réaliste à déployer, plutôt qu'un `nginx` isolé.

**🧠 Analogie**
C'est une maquette de ville : simple mais représentative, avec une vitrine (frontend), une administration (backend) et des archives (base de données) qui interagissent vraiment entre elles.

**❓ Pourquoi**
Elle permet de démontrer une vraie architecture multi-services avec dépendances réseau.

**🛠️ Prompt Claude Code**
```
Crée une petite application 3-tiers : frontend statique, backend API
simple (Python ou Node), PostgreSQL. Chaque composant dans son propre
dossier, prêt à être conteneurisé.
```

---

## Étape 2 — Docker

**🎯 Le concept**
Construire des images légères et sécurisées : multi-stage build, utilisateur non-root, image minimale, healthcheck.

**🧠 Analogie**
Le multi-stage build, c'est comme ne servir au client que l'assiette finale — pas toute la cuisine (compilateurs, outils) qui a servi à préparer le plat.

**❓ Pourquoi**
Moins de binaires dans l'image finale = moins de vulnérabilités et image plus légère. Non-root limite les dégâts si le conteneur est compromis.

**🛠️ Prompt Claude Code**
```
Crée un Dockerfile multi-stage pour le backend : image finale minimale
(distroless ou alpine), utilisateur non-root, et un HEALTHCHECK.
```

---

## Étape 3 — Helm

**🎯 Le concept**
Templater et packager les manifests Kubernetes, avec des valeurs différentes selon l'environnement.

**🧠 Analogie**
Un chart Helm est un moule à gâteau réutilisable ; `values.yaml` est la recette qui change selon si tu fais un gâteau pour 4 (dev) ou 40 personnes (prod) — le moule reste le même.

**❓ Pourquoi**
Évite de dupliquer des dizaines de YAML, versionne les déploiements, facilite les rollbacks.

**🛠️ Prompt Claude Code**
```
Crée un Helm chart pour l'application avec values-dev.yaml et
values-prod.yaml (replicas, resources, domaine différents).
```

---

## Étape 4 — Socle de sécurité Kubernetes

**🎯 Le concept**
Appliquer par défaut : Namespace dédié, RBAC, ResourceQuota, LimitRange, SecurityContext, NetworkPolicy.

**🧠 Analogie**
Comme le règlement d'un immeuble partagé : chaque locataire (namespace) a sa porte fermée à clé (RBAC), un budget électrique max pour ne pas gêner les voisins (ResourceQuota/LimitRange), et un règlement de circulation qui dit « frontend peut parler à backend, mais pas directement à la cave où sont les archives » (NetworkPolicy).

**❓ Pourquoi**
Limite le "blast radius" en cas de compromission, empêche un pod buggé de consommer toutes les ressources du cluster, applique une segmentation réseau zero-trust.

**🛠️ Prompt Claude Code**
```
Applique un socle de sécurité au namespace : ServiceAccount dédié, RBAC
minimal, ResourceQuota, LimitRange, SecurityContext (runAsNonRoot,
readOnlyRootFilesystem), et une NetworkPolicy autorisant
frontend→backend→postgresql mais bloquant frontend→postgresql direct.
```

---

## Étape 5 — Ingress & TLS

**🎯 Le concept**
Un point d'entrée unique pour le trafic externe, avec certificats HTTPS renouvelés automatiquement.

**🧠 Analogie**
L'Ingress est le standard d'accueil d'un immeuble : une seule porte (une IP publique) qui redirige chaque visiteur vers le bon bureau (`/` → frontend, `/api` → backend). Cert-manager est l'agent qui renouvelle le badge de sécurité (certificat TLS) avant qu'il n'expire, sans intervention humaine.

**❓ Pourquoi**
Évite d'exposer chaque service individuellement, et évite les coupures de service dues à un certificat expiré et oublié.

**🛠️ Prompt Claude Code**
```
Installe un Ingress Controller nginx, configure cert-manager avec un
ClusterIssuer Let's Encrypt, et crée une Ingress routant / vers frontend
et /api vers backend avec TLS automatique.
```

---

## Étape 6 — GitOps avec Argo CD

**🎯 Le concept**
Git devient la seule source de vérité de l'état désiré du cluster. Argo CD compare en continu l'état réel à l'état déclaré et corrige l'écart.

**🧠 Analogie**
Argo CD est un thermostat. Tu définis la température désirée dans Git (20°C), et le thermostat corrige en continu l'écart avec la température réelle de la pièce (le cluster), sans intervention manuelle.

**❓ Pourquoi**
Traçabilité totale (chaque changement = un commit avec review), auto-guérison contre le drift, cohérence entre environnements.

**🛠️ Prompt Claude Code**
```
Installe Argo CD, crée une Application pointant vers le repo Git du
Helm chart, en mode auto-sync avec self-heal activé.
```

**Démonstration du drift à faire soi-même :**
```bash
kubectl scale deployment backend --replicas=5
# observer Argo CD ramener automatiquement à l'état désiré (3 replicas)
```

---

## Étape 7 — Secrets (External Secrets Operator + Vault)

**🎯 Le concept**
Ne jamais stocker de secret en clair dans Git ; le récupérer dynamiquement depuis un coffre-fort centralisé.

**🧠 Analogie**
Vault est le coffre-fort central d'une banque. External Secrets Operator est le coursier de confiance qui va chercher uniquement le document dont l'application a besoin, au moment voulu, sans jamais en laisser une copie traîner dans le dossier public (Git).

**❓ Pourquoi**
Les Kubernetes Secrets bruts ne sont que de l'encodage base64, pas du chiffrement. Vault centralise chiffrement, rotation et audit d'accès.

**🛠️ Prompt Claude Code**
```
Déploie External Secrets Operator, connecte-le à Vault, et crée un
ExternalSecret qui synchronise le mot de passe PostgreSQL depuis Vault
vers un Kubernetes Secret consommé par le backend.
```

---

## Étape 8 — FinOps sur Kubernetes (ajout)

**🎯 Le concept**
Donner de la visibilité sur le coût réel de chaque application/équipe sur le cluster, et dimensionner correctement les ressources pour éviter le gaspillage.

**🧠 Analogie**
C'est comme installer un compteur électrique individuel dans chaque appartement d'un immeuble, au lieu d'une seule facture globale. Chaque équipe voit précisément combien lui coûte son application, et peut ajuster sa consommation en conséquence.

**❓ Pourquoi c'est important**
Sans visibilité, personne ne sait quelle appli coûte cher. Sans bon dimensionnement des `requests`/`limits` :
- trop hautes → gaspillage (on paie des ressources réservées mais inutilisées)
- trop basses → instabilité (CPU throttling, OOMKill)

**🛠️ Ce qu'on met en place**
1. **Resource requests/limits réalistes** dans le Helm chart, basés sur l'usage réel observé (via Prometheus, cf. Projet 3).
2. **OpenCost** (ou Kubecost) connecté à Prometheus, pour visualiser le coût par namespace, par label `team`, par appli.
3. Un dashboard Grafana dédié au coût, et une alerte si un namespace dépasse un budget attendu.

**🛠️ Prompt Claude Code**
```
Installe OpenCost sur le cluster, connecté à Prometheus, pour visualiser
le coût par namespace et par label "team". Ajoute des resources.requests
et limits cohérents dans le Helm chart de l'application (ex: 100m CPU /
128Mi requests, 500m CPU / 256Mi limits), et crée un dashboard Grafana
simple affichant le coût estimé par namespace.
```

---

## Prochaine étape suggérée

Le Projet 3 (**Observability & SRE**) s'appuie directement sur cette plateforme : les métriques Prometheus qu'on vient de commencer à utiliser pour le FinOps deviennent le socle de l'observabilité complète (logs, traces, SLI/SLO).
