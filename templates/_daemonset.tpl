{{/*
  Returns the name for a DaemonSet resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.daemonset.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{/*
  Renders the labels for a DaemonSet and its pod template.
  Delegates to core.deployment.labels — same standard label set including
  the optional commit label sourced from global.commit.
  @param  $              {object}          Helm root context
  @param  global.commit  {string|integer}  git commit SHA or build number (optional)
  @return {string}  YAML key-value label block
*/}}
{{- define "core.daemonset.labels" -}}
{{- include "core.deployment.labels" . }}
{{- end }}
