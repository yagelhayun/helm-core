{{/*
  Returns the name for a HorizontalPodAutoscaler resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.hpa.name" -}}
{{- include "core.general.name" . }}
{{- end }}
