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

{{/*
  Returns the desired replica count, enforcing zero replicas in inactive regions.
  When activeRegion is set and does not match global.region the deployment is
  scaled to 0, supporting blue/green and regional active/standby patterns.
  @param  replicas      {integer}  desired replica count
  @param  activeRegion  {string}   the region that should run live pods (optional)
  @param  region        {string}   the current region (from global.region after config merge)
  @return {integer}  replica count — either the configured value or 0
*/}}
{{- define "core.deployment.replicas" -}}
{{- ternary .replicas 0 (or (not .activeRegion) (eq .activeRegion .region)) }}
{{- end }}
