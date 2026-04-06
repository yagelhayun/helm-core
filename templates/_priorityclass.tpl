{{/*
  Validates that a PriorityClass exists in the cluster.
  PriorityClass is cluster-scoped (no namespace) and uses the scheduling.k8s.io/v1 API.
  No-ops silently when not running against a real cluster (helm template,
  dry-run, or global.ignoreLookup: "true") — see core.isRealDeployment.
  Fails the render if the PriorityClass does not exist during a live deployment.
  @param  $     {object}  Helm root context
  @param  name  {string}  name of the PriorityClass to validate
  @return {string}  empty string (called for its fail side-effect only)
*/}}
{{- define "core.priorityclass.get" -}}
{{- $ := (index . "$") }}
{{- include "core.cluster.getResource" (dict "$" $ "name" .name "type" "PriorityClass" "version" "scheduling.k8s.io/v1" "namespace" "") -}}
{{- end }}
