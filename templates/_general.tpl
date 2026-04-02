{{/*
  * Name of the chart
  * @param $
*/}}
{{- define "core.general.name" -}}
{{- $ := (index . "$") -}}
{{- $.Chart.Name }}
{{- end }}

{{- define "core.general.mergeRegionConfig" -}}
{{- $ := (index . "$") -}}
{{ $desiredRegion := required "Missing region property" ($.Values.global).region }}
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

{{- define "core.general.config" -}}
{{- $rootValues := include "core.general.mergeRegionConfig" (dict "$" $ "valuesScope" .Values) | fromYaml }}
{{- $globalValues := include "core.general.mergeRegionConfig" (dict "$" $ "valuesScope" .Values.global) | fromYaml }}
{{- omit (merge $rootValues $globalValues) "global" "regions" | toYaml }}
{{- end }}

{{/*
  * NOTE: There is intentionally no "core.general.context" helper.
  *
  * Building the full context dict requires holding a live reference to the Helm
  * root context ($), which cannot be serialized through toYaml/fromYaml (the only
  * way to return values from a named template). The two-line setup below is therefore
  * the minimal necessary boilerplate in every consumer template:
  *
  *   {{- $config := include "core.general.config" . | fromYaml }}
  *   {{- $context := merge (dict "$" $) $config }}
*/}}
