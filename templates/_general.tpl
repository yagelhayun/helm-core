{{/*
  Returns the chart name, used as the base name for all resources.
  @param  $  {object}  Helm root context
  @return {string}  $.Chart.Name
*/}}
{{- define "core.general.name" -}}
{{- $ := (index . "$") -}}
{{- $.Chart.Name }}
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
