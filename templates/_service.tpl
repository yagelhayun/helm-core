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
  Looks up a Service resource from the cluster by name.
  No-ops during non-live renders (helm template, dry-run).
  Fails the render if the Service is missing during a live deployment.
  @param  $     {object}  Helm root context
  @param  name  {string}  Service name to look up
  @return {string}  YAML-encoded Service object, or empty string during non-live renders
*/}}
{{- define "core.service.get" -}}
{{- $ := (index . "$") }}
{{- include "core.cluster.getResource" (dict "$" $ "type" "Service" "name" .name) }}
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
