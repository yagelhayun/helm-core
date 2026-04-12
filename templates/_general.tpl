{{/*
  Returns "true" when the chart is the root chart, "false" when it is a sub-chart.
  Detected by comparing the first path segment of $.Template.Name (always the
  root chart's directory name) against $.Chart.Name.
  @param  $  {object}  Helm root context
  @return {string}  "true" | "false"
*/}}
{{- define "core.general.isRootChart" -}}
{{- $ := (index . "$") -}}
{{- eq (splitList "/" (default "" $.Template.Name) | first) (default "" $.Chart.Name) }}
{{- end }}

{{/*
  Returns the base name used for all resources.
  For root charts, defaults to $.Release.Name so resources are named after the
  deployment with no configuration required.
  For sub-charts, nameOverride is required — there is no sensible automatic
  default since all sub-charts share the same release name, and silently
  defaulting to the chart name would risk label collisions if the same chart
  is included twice under different aliases.
  @param  $             {object}  Helm root context
  @param  nameOverride  {string}  optional for root charts; required for sub-charts
  @return {string}  resource base name
*/}}
{{- define "core.general.name" -}}
{{- $ := (index . "$") -}}
{{- if eq (include "core.general.isRootChart" .) "true" }}
{{- .nameOverride | default $.Release.Name }}
{{- else }}
{{- required (printf "Subchart '%s' must set nameOverride" $.Chart.Name) .nameOverride }}
{{- end }}
{{- end }}

{{/*
  Renders the stable label set used as pod selector and pod template labels.
  These labels must never change for the lifetime of a release — they are used
  in spec.selector.matchLabels (immutable after creation) and
  spec.template.metadata.labels (must satisfy the selector).
  @param  $  {object}  Helm root context
  @return {string}  YAML key-value label block
*/}}
{{- define "core.general.selectorLabels" -}}
{{- $ := (index . "$") -}}
app.kubernetes.io/name: {{ include "core.general.name" . | quote }}
{{- end }}

{{/*
  Renders the full label set applied to resource metadata.
  Includes helm.sh/chart (which carries the chart version) and managed-by,
  so it must NOT be used at spec.selector or pod template level.
  Workload-specific labels (e.g. commit SHA) are added by the caller via
  core.workload.labels / core.daemonset.labels / core.statefulset.labels.
  @param  $  {object}  Helm root context (for Chart.Name, Chart.Version, Release.Service)
  @return {string}  YAML key-value label block
*/}}
{{- define "core.general.labels" -}}
{{- $ := (index . "$") -}}
{{- include "core.general.selectorLabels" . }}
helm.sh/chart: {{ printf "%s-%s" $.Chart.Name $.Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ $.Release.Service | quote }}
{{- end }}

{{/*
  Merges region-specific values on top of a given values scope.
  Looks up the key matching global.region inside the scope's "regions" map
  and deep-merges it over the scope itself, so region keys win over root keys.
  If no "regions" map is present the scope is returned unchanged.
  This is an internal helper — consumers should call core.general.config.
  @param  $            {object}  Helm root context (for global.region)
  @param  valuesScope  {object}  the values object to merge into (e.g. .Values or .Values.global)
  @return {string}  YAML-encoded merged values object
*/}}
{{- define "core.general.mergeRegionConfig" -}}
{{- $ := (index . "$") -}}
{{ $desiredRegion := ($.Values.global).region }}
{{ $commonValues := .valuesScope }}
{{/* Create a copy of regions so merging the sub-object back into the root doesn't cause an infinite loop */}}
{{ $regions := toYaml (.valuesScope).regions | fromYaml }}
{{- if empty $regions }}
{{ tpl ($commonValues | toYaml) $ }}
{{- else }}
{{ $regionValues := ternary (index $regions $desiredRegion) dict (hasKey $regions $desiredRegion) }}
{{ tpl (merge $regionValues $commonValues | toYaml) $ }}
{{- end }}
{{- end }}

{{/*
  Builds the resolved configuration object used by all resource templates.
  Merges values in priority order (highest → lowest):
    1. Region-specific root values  (regions.<region>.*)
    2. Root values                  (.Values.*)
    3. Region-specific global values (global.regions.<region>.*)
    4. Global values                (.Values.global.*)
  The resulting object is stripped of "global" and "regions" keys and is
  intended to be merged with the Helm root context via:
    {{- $config  := include "core.general.config" . | fromYaml }}
    {{- $context := merge (dict "$" $) $config }}
  @param  $  {object}  Helm root context
  @return {string}  YAML-encoded flat config object ready for fromYaml
*/}}
{{- define "core.general.config" -}}
{{- $rootValues := include "core.general.mergeRegionConfig" (dict "$" $ "valuesScope" .Values) | fromYaml }}
{{- $globalValues := include "core.general.mergeRegionConfig" (dict "$" $ "valuesScope" .Values.global) | fromYaml }}
{{- omit (merge $rootValues $globalValues) "global" "regions" | toYaml }}
{{- end }}
