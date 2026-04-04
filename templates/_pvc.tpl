{{/*
  Fetches a PersistentVolumeClaim from the cluster by name.
  No-ops silently when not running against a real cluster (helm template,
  dry-run, or global.ignoreLookup: "true") — see core.isRealDeployment.
  Fails the render if the PVC does not exist during a live deployment.
  @param  $     {object}  Helm root context
  @param  name  {string}  name of the PersistentVolumeClaim to look up
  @return {object}  the PVC resource as a YAML object, or empty if not a real deployment
*/}}
{{- define "core.pvc.get" -}}
{{- $ := (index . "$") }}
{{- include "core.cluster.getResource" (dict "$" $ "name" .name "type" "PersistentVolumeClaim") -}}
{{- end }}
