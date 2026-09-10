# Configuration Vault pour External Secrets Operator

Ces commandes ne sont **pas** déclaratives via YAML (Vault n'a pas d'API
Kubernetes native — c'est justement tout l'intérêt d'ESO : faire le pont
entre les deux mondes). Elles configurent Vault lui-même, une seule fois,
avant que `clustersecretstore.yaml` puisse fonctionner.

⚠️ Vault ici tourne en **mode dev** (`server.dev.enabled=true`,
`Storage Type: inmem`) : stockage en mémoire, tout est perdu au
redémarrage du pod (vécu en pratique pendant cette Étape 7 : un
remplacement du node pool a effacé une première tentative de
configuration). Acceptable pour valider le flux ESO ↔ Vault dans un lab —
en production, un Vault réel a un stockage persistant, un vrai processus
de scellement (unseal), et n'expose jamais son root token dans les logs
d'installation comme le fait le mode dev.

```bash
# 1. Active l'authentification Kubernetes (Vault vérifie le jeton de
#    ServiceAccount d'ESO directement auprès de l'API Kubernetes du cluster
#    — aucune clé Vault statique à distribuer à ESO).
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

kubectl exec -n vault vault-0 -- sh -c '
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"
'

# 2. Politique : lecture seule, uniquement sous secret/task-tracker/*
kubectl exec -n vault vault-0 -- sh -c '
vault policy write task-tracker-postgres - <<EOF
path "secret/data/task-tracker/*" {
  capabilities = ["read"]
}
EOF
'

# 3. Rôle : lie CE policy au ServiceAccount "external-secrets" du
#    namespace "external-secrets", et à lui seul — un pod compromis dans
#    n'importe quel autre namespace ne peut pas s'authentifier avec ce rôle.
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/eso-task-tracker \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=task-tracker-postgres \
  ttl=1h

# 4. Le secret réel — la même valeur déjà utilisée par le pod Postgres en
#    place (changer la valeur ici NE change PAS le mot de passe déjà
#    initialisé dans Postgres : voir la note dans charts/app/templates/backend-secret.yaml
#    sur l'écart entre "secret utilisé à l'initialisation" et "secret modifiable après coup").
kubectl exec -n vault vault-0 -- vault kv put secret/task-tracker/postgres \
  password="dev-cluster-test-only"
```
