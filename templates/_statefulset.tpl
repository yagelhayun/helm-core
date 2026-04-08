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

{{/*
  Renders a volumeClaimTemplates list for a StatefulSet.
  Each entry becomes a PersistentVolumeClaim created and managed by the
  StatefulSet controller — one per pod replica, named "<name>-<pod-name>".
  Note: volumeClaimTemplates is a Kubernetes field only valid on StatefulSet.
  The helper lives in core so any consumer chart can call it without
  reimplementing the rendering logic.
  @param  statefulSet.volumeClaimTemplates  {array}  list of volume claim specs:
            - name         {string}  claim name (required)
            - size         {string}  storage request, e.g. "10Gi" (required)
            - storageClass {string}  StorageClass name (optional — cluster default if omitted)
            - accessMode   {string}  "ReadWriteOnce" (default) | "ReadWriteMany" | "ReadOnlyMany"
  @return {string}  YAML list of volumeClaimTemplate objects, or empty string
*/}}
{{- define "core.statefulset.volumeClaimTemplates" -}}
{{- range (.statefulSet).volumeClaimTemplates }}
- metadata:
    name: {{ .name }}
  spec:
    {{- with .storageClass }}
    storageClassName: {{ . }}
    {{- end }}
    accessModes:
      - {{ .accessMode | default "ReadWriteOnce" }}
    resources:
      requests:
        storage: {{ .size }}
{{- end }}
{{- end }}