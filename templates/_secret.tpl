{{/*
  * Gets a secret from the cluster and fails if it doesnt exist
  * @param name
*/}}
{{- define "core.secret.get" -}}
{{- $ := (index . "$") }}
{{- include "core.cluster.getResource" (dict "$" $ "name" .name "type" "Secret") -}}
{{- end }}
