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
