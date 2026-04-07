{{/*
  Renders a strategy/updateStrategy block for any workload kind.

  The rollingUpdate sub-fields depend on the workload type:
  - Deployment/DaemonSet: maxUnavailable + maxSurge (percentage defaults scale with replica count)
  - StatefulSet:          partition only (set strategy.partition for canary ordinal rollouts)

  The presence of strategy.partition is used as the discriminator — set it to
  switch to StatefulSet rolling-update mode. Recreate and OnDelete produce no
  rollingUpdate block at all.

  Note: the caller is responsible for the correct field name in the manifest
  (Deployment uses "strategy:", StatefulSet/DaemonSet use "updateStrategy:").

  @param  strategy.type           {string}          "RollingUpdate" (default) | "Recreate" | "OnDelete"
  @param  strategy.partition      {integer}         StatefulSet ordinal partition for canary rollouts (optional)
  @param  strategy.maxUnavailable {string|integer}  Deployment/DaemonSet: max pods unavailable (default: "25%")
  @param  strategy.maxSurge       {string|integer}  Deployment/DaemonSet: max pods above desired (default: "25%")
  @return {string}  YAML strategy block
*/}}
{{- define "core.workload.strategy" -}}
{{- $type := (.strategy).type | default "RollingUpdate" -}}
type: {{ $type }}
{{- if eq $type "RollingUpdate" }}
rollingUpdate:
  {{- with (.strategy).partition }}
  partition: {{ . }}
  {{- else }}
  maxUnavailable: {{ (.strategy).maxUnavailable | default "25%" | quote }}
  maxSurge: {{ (.strategy).maxSurge | default "25%" | quote }}
  {{- end }}
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
{{- define "core.workload.replicas" -}}
{{- ternary .replicas 0 (or (not .activeRegion) (eq .activeRegion .region)) }}
{{- end }}

{{/*
  Renders the labels for a workload and its pod template.
  Extends core.general.labels with an optional commit label sourced from
  global.commit, which can be used to correlate a workload with a git SHA.
  @param  $              {object}           Helm root context
  @param  global.commit  {string|integer}   git commit SHA or build number (optional)
  @return {string}  YAML key-value label block
*/}}
{{/*
  Returns the revisionHistoryLimit for a workload, defaulting to 1.
  Uses ternary+kindIs to distinguish "not set" (nil) from an explicit 0.
  @param  revisionHistoryLimit  {integer}  number of old ReplicaSets to retain (optional)
  @return {integer}  revisionHistoryLimit value
*/}}
{{- define "core.workload.revisionHistoryLimit" -}}
{{- ternary 1 (int .revisionHistoryLimit) (kindIs "invalid" .revisionHistoryLimit) }}
{{- end }}

{{- define "core.workload.labels" -}}
{{- include "core.general.labels" . -}}
{{- $ := (index . "$") }}
{{- with $.Values.global.commit }}
{{- $isNumber := or (typeIs "float64" .) (typeIs "int64" .) }}
commit: {{ ternary (int .) (.) $isNumber | quote }}
{{- end }}
{{- end }}
