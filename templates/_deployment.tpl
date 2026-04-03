{{/*
  Returns the name for a Deployment resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.deployment.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{/*
  Renders the labels for a Deployment and its pod template.
  Extends core.common.labels with an optional commit label sourced from
  global.commit, which can be used to correlate a deployment with a git SHA.
  @param  $              {object}           Helm root context
  @param  global.commit  {string|integer}   git commit SHA or build number (optional)
  @return {string}  YAML key-value label block
*/}}
{{- define "core.deployment.labels" -}}
{{- include "core.common.labels" . -}}
{{- $ := (index . "$") }}
{{- with $.Values.global.commit }}
{{- $isNumber := or (typeIs "float64" .) (typeIs "int64" .) }}
commit: {{ ternary (int .) (.) $isNumber | quote }}
{{- end }}
{{- end }}
