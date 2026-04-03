{{/*
  Renders the deployment strategy block.
  Defaults to RollingUpdate with percentage-based values so the budget scales
  automatically with replica count: 25% rounds down to 0 unavailable for a
  single-replica deployment (no downtime) and up to 1 for surge.
  Set strategy.type: Recreate to terminate all existing pods before new ones start.
  @param  strategy.type           {string}  "RollingUpdate" (default) | "Recreate"
  @param  strategy.maxUnavailable {string|integer}  max pods unavailable during rollout (default: "25%")
  @param  strategy.maxSurge       {string|integer}  max pods above desired count during rollout (default: "25%")
  @return {string}  YAML strategy block (type + optional rollingUpdate)
*/}}
{{- define "core.common.strategy" -}}
{{- $type := (.strategy).type | default "RollingUpdate" -}}
type: {{ $type }}
{{- if eq $type "RollingUpdate" }}
rollingUpdate:
  maxUnavailable: {{ (.strategy).maxUnavailable | default "25%" | quote }}
  maxSurge: {{ (.strategy).maxSurge | default "25%" | quote }}
{{- end }}
{{- end }}

{{/*
  Renders the standard set of labels applied to every resource and pod selector.
  These labels are also used as the labelSelector in topology spread constraints
  and Service selectors, so they must remain stable across chart upgrades.
  @param  $  {object}  Helm root context (for Chart.Name, Chart.Version, Release.Service)
  @return {string}  YAML key-value label block
*/}}
{{- define "core.common.labels" -}}
{{- $ := (index . "$") -}}
app.kubernetes.io/name: {{ include "core.general.name" . | quote }}
helm.sh/chart: {{ printf "%s-%s" $.Chart.Name $.Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ $.Release.Service | quote }}
{{- end }}
