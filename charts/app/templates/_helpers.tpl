{{/*
Helpers de nommage — évite de répéter "{{ .Release.Name }}-xxx" et le même
jeu de labels dans chaque template. Étape 4 (RBAC/NetworkPolicy) s'appuiera
sur ces mêmes labels pour cibler les bons pods sans les redéfinir ailleurs.
*/}}

{{- define "app.backendImage" -}}
{{- if .Values.imageRegistry }}{{ .Values.imageRegistry }}/{{ end }}{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}
{{- end -}}

{{- define "app.frontendImage" -}}
{{- if .Values.imageRegistry }}{{ .Values.imageRegistry }}/{{ end }}{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}
{{- end -}}

{{- define "app.postgresImage" -}}
{{- if .Values.imageRegistry }}{{ .Values.imageRegistry }}/{{ end }}{{ .Values.postgres.image.repository }}:{{ .Values.postgres.image.tag }}
{{- end -}}

{{/* Nom du Secret contenant PGPASSWORD : celui géré par ce chart, ou un
     Secret déjà existant (ex. créé par l'ExternalSecret de l'Étape 7). */}}
{{- define "app.postgresSecretName" -}}
{{- if .Values.postgres.existingSecret -}}
{{ .Values.postgres.existingSecret }}
{{- else -}}
{{ .Release.Name }}-postgres
{{- end -}}
{{- end -}}

{{/* Hôte Postgres que le backend doit contacter : le Service in-cluster
     créé par ce chart, ou un hôte externe (ex. Cloud SQL) en prod. */}}
{{- define "app.postgresHost" -}}
{{- if .Values.postgres.enabled -}}
{{ .Release.Name }}-db
{{- else -}}
{{ required "postgres.host est requis quand postgres.enabled=false (voir values-prod.yaml)" .Values.postgres.host }}
{{- end -}}
{{- end -}}
