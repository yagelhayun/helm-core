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

{{/*
  Renders the scaleTargetRef block for an HPA.
  @param  $       {object}  Helm root context (via merged $context)
  @return {string}  YAML scaleTargetRef block
*/}}
{{- define "core.hpa.workloadRef" -}}
kind: {{ .workload.type }}
name: {{ include (printf "core.%s.name" (lower .workload.type)) . }}
apiVersion: apps/v1
{{- end }}

{{/*
  Renders the metrics list for an HPA from hpa.resources.
  Each entry in resources becomes a Resource-type metric with averageUtilization.
  Defaults averageUtilization to 70 if not set.
  @param  config  {object}  the resolved config map (core.general.config output)
  @return {string}  YAML metrics list (without the leading "metrics:" key)
*/}}
{{- define "core.hpa.metrics" -}}
{{- range $resource, $target := .hpa.resources }}
- type: Resource
  resource:
    name: {{ $resource }}
    target:
      type: Utilization
      averageUtilization: {{ $target.averageUtilization | default 70 }}
{{- end }}
{{- end }}
