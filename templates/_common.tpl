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
{{- define "core.common.strategy" -}}
{{- $type := (.strategy).type | default "RollingUpdate" -}}
type: {{ $type }}
{{- if eq $type "RollingUpdate" }}
rollingUpdate:
  {{- if not (kindIs "invalid" (.strategy).partition) }}
  partition: {{ (.strategy).partition }}
  {{- else }}
  maxUnavailable: {{ (.strategy).maxUnavailable | default "25%" | quote }}
  maxSurge: {{ (.strategy).maxSurge | default "25%" | quote }}
  {{- end }}
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

{{/*
  Returns the desired replica count, enforcing zero replicas in inactive regions.
  When activeRegion is set and does not match global.region the deployment is
  scaled to 0, supporting blue/green and regional active/standby patterns.
  @param  replicas      {integer}  desired replica count
  @param  activeRegion  {string}   the region that should run live pods (optional)
  @param  region        {string}   the current region (from global.region after config merge)
  @return {integer}  replica count — either the configured value or 0
*/}}
{{- define "core.common.replicas" -}}
{{- ternary .replicas 0 (or (not .activeRegion) (eq .activeRegion .region)) }}
{{- end }}
