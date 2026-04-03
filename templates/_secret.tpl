{{/*
  Fetches a Secret from the cluster by name.
  No-ops silently when not running against a real cluster (helm template,
  dry-run, or global.ignoreLookup: "true") — see core.isRealDeployment.
  Fails the render if the Secret does not exist during a live deployment.
  @param  $     {object}  Helm root context
  @param  name  {string}  name of the Secret to look up
  @return {object}  the Secret resource as a YAML object, or empty if not a real deployment
*/}}
{{- define "core.secret.get" -}}
{{- $ := (index . "$") }}
{{- include "core.cluster.getResource" (dict "$" $ "name" .name "type" "Secret") -}}
{{- end }}
