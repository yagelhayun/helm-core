{{- define "core.deployment.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{- define "core.deployment.labels" -}}
{{- include "core.common.labels" . -}}
{{- $ := (index . "$") }}
{{- with $.Values.global.commit }}
{{- $isNumber := or (typeIs "float64" .) (typeIs "int64" .) }}
commit: {{ ternary (int .) (.) $isNumber | quote }}
{{- end }}
{{- end }}

{{- define "core.deployment.replicas" -}}
{{- $replicas := required "Missing replicas property" .replicas }}
{{- ternary .replicas 0 (or (not .activeRegion) (eq .activeRegion .region)) }}
{{- end }}
