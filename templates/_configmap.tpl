{{/*
  Returns the name for a ConfigMap resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.configmap.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{/*
  Fetches a ConfigMap from the cluster by name.
  No-ops silently when not running against a real cluster (helm template,
  dry-run, or global.ignoreLookup: "true") — see core.isRealDeployment.
  Fails the render if the ConfigMap does not exist during a live deployment.
  @param  $     {object}  Helm root context
  @param  name  {string}  name of the ConfigMap to look up
  @return {object}  the ConfigMap resource as a YAML object, or empty if not a real deployment
*/}}
{{- define "core.configmap.get" -}}
{{- $ := (index . "$") }}
{{- include "core.cluster.getResource" (dict "$" $ "name" .name "type" "ConfigMap") -}}
{{- end }}
