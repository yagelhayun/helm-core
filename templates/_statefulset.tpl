{{/*
  Returns the name for a StatefulSet resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.statefulset.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{/*
  Validates that the headless Service referenced by a StatefulSet exists in the cluster.
  No-ops during non-live renders (helm template, dry-run).
  Fails the render if the Service is missing during a live deployment.
  @param  $     {object}  Helm root context
  @param  name  {string}  headless Service name (statefulSet.headlessService)
*/}}
{{/*
  Returns the podManagementPolicy for a StatefulSet, defaulting to OrderedReady.
  @param  statefulSet.podManagementPolicy  {string}  "OrderedReady" (default) | "Parallel"
  @return {string}  podManagementPolicy value
*/}}
{{- define "core.statefulset.podManagementPolicy" -}}
{{- (.statefulSet).podManagementPolicy | default "OrderedReady" }}
{{- end }}

{{- define "core.statefulset.headlessService" -}}
{{- $ := (index . "$") }}
{{- $_ := include "core.service.get" (dict "$" $ "name" .statefulSet.headlessService) -}}
{{- .statefulSet.headlessService -}}
{{- end }}
