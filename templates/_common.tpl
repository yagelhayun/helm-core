{{/*
  * Rolling Update Strategy
*/}}
{{- define "core.common.strategy.rollingUpdate" -}}
rollingUpdate:
  maxSurge: 1
  maxUnavailable: 1
type: RollingUpdate
{{- end }}

{{/*
  * Recreate Strategy
*/}}
{{- define "core.common.strategy.recreate" -}}
type: Recreate
{{- end }}

{{- define "core.common.labels" -}}
app.kubernetes.io/name: {{ include "core.general.name" . | quote }}
{{- end }}
