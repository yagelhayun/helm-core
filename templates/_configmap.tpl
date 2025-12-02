{{- define "core.configmap.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{/*
  * Gets a configMap from the cluster and fails if it doesnt exist
  * @param name
*/}}
{{- define "core.configmap.get" -}}
{{- $ := (index . "$") }}
{{- include "core.cluster.getResource" (dict "$" $ "name" .name "type" "ConfigMap") -}}
{{- end }}
