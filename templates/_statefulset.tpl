{{/*
  Returns the name for a StatefulSet resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.statefulset.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{/*
  Renders the labels for a StatefulSet and its pod template.
  Delegates to core.deployment.labels — same standard label set including
  the optional commit label sourced from global.commit.
  @param  $              {object}          Helm root context
  @param  global.commit  {string|integer}  git commit SHA or build number (optional)
  @return {string}  YAML key-value label block
*/}}
{{- define "core.statefulset.labels" -}}
{{- include "core.deployment.labels" . }}
{{- end }}
