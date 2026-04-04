{{/*
  Returns the name for a PodDisruptionBudget resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.pdb.name" -}}
{{- include "core.general.name" . }}
{{- end }}
