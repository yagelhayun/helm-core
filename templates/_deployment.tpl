{{- define "core.deployment.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{- define "core.deployment.labels" -}}
{{- include "core.common.labels" . -}}
{{- $ := (index . "$") }}
{{- $commit := required "Missing commit property" $.Values.global.commit }}
{{- $isNumber := or (typeIs "float64" $commit) (typeIs "int64" $commit) }}
commit: {{ ternary (int $commit) ($commit) $isNumber | quote }}
{{- end }}

{{- define "core.deployment.replicas" -}}
{{- $replicas := required "Missing replicas property" .replicas }}
{{- ternary .replicas 0 (or (not .activeRegion) (eq .activeRegion .region)) }}
{{- end }}
