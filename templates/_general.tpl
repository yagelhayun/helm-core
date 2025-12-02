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
{{ $desiredRegion := required "Missing region property" $.Values.global.region }}
{{ $commonValues := .valuesScope }}
{{ $regions := toYaml (.valuesScope).regions | fromYaml }} # Here we create a copy of the regions object so we won't create an infinite loop afterwards (merging the a sub-object in the root object)
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
