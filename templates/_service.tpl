{{/*
  Returns the name for a Service resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.service.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{/*
  Returns the Service type.
  Reads service.type from config; defaults to ClusterIP.
  Supported values: ClusterIP, NodePort, LoadBalancer
  @param  $  {object}  Helm root context (merged with config via $context)
  @return {string}  service type
*/}}
{{- define "core.service.type" -}}
{{- (.service).type | default "ClusterIP" }}
{{- end }}
