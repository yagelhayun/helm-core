{{/*
  Renders the volumes list for a pod spec.
  Supports four volume types: secrets (mounted from a Secret), configMaps
  (mounted from a ConfigMap), empty (emptyDir), and persistentVolumeClaims
  (referencing an existing PVC). Each type is iterated separately and
  validated against the cluster during live deployments.
  @param  $                                      {object}  Helm root context (for cluster lookups)
  @param  volumes.secrets             {object}  map of Secret name → { mountPath, defaultMode?, files? }
  @param  volumes.configMaps          {object}  map of ConfigMap name → { mountPath, defaultMode?, files? }
  @param  volumes.empty               {object}  map of volume name → { mountPath }
  @param  volumes.persistentVolumeClaims {object}  map of PVC name → { mountPath, readOnly? }
  @return {string}  YAML list of volume objects, or empty string if no volumes
*/}}
{{- define "core.pod.volumes" -}}
{{- $ := (index . "$") }}
{{- $defaultPermissions := 420 }}
{{- with .volumes }}
{{- range $resourceName, $resourceParams := .configMaps }}
{{- $configMap := include "core.configmap.get" (dict "$" $ "name" $resourceName) | fromYaml }}
- name: {{ $resourceName }}
  configMap:
    name: {{ $resourceName }}
    defaultMode: {{ ($resourceParams).defaultMode | default $defaultPermissions }}
{{- end }}
{{- range $resourceName, $resourceParams := .secrets }}
{{- $secret := include "core.secret.get" (dict "$" $ "name" $resourceName) | fromYaml }}
- name: {{ $resourceName }}
  secret:
    secretName: {{ $resourceName }}
    defaultMode: {{ ($resourceParams).defaultMode | default $defaultPermissions }}
{{- end }}
{{- range $volumeName, $_ := .empty }}
- name: {{ $volumeName }}
  emptyDir: {}
{{- end }}
{{- range $resourceName, $resourceParams := .persistentVolumeClaims }}
{{- $pvc := include "core.pvc.get" (dict "$" $ "name" $resourceName) | fromYaml }}
- name: {{ $resourceName }}
  persistentVolumeClaim:
    claimName: {{ $resourceName }}
    {{- if ($resourceParams).readOnly }}
    readOnly: true
    {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  Renders the imagePullSecrets list for a pod spec.
  Resolves pull secrets from image.pullSecrets, falling back to
  global.image.pullSecrets when the local value is not set.
  @param  image.pullSecrets        {array}  list of pull secret names (optional)
  @param  global.image.pullSecrets {array}  global fallback list of pull secret names (optional)
  @return {string}  YAML list of { name: ... } objects, or empty string
*/}}
{{- define "core.pod.imagePullSecrets" -}}
{{- $pullSecrets := (.image).pullSecrets | default ((.global).image).pullSecrets }}
{{- range $pullSecrets }}
- name: {{ . }}
{{- end }}
{{- end }}

{{/*
  Renders the initContainers list for a pod spec.
  Delegates each entry to core.container.render. Pod-level volumes used by
  init containers must be declared in the root volumes config.
  Note: the individual init container config is passed as context, so cluster
  lookups (env.secrets, env.configMaps) are not supported in init containers.
  @param  initContainers  {array}  list of container config objects (see core.container.render)
  @return {string}  YAML list of init container objects, or empty string
*/}}
{{- define "core.pod.initContainers" }}
{{- range .initContainers }}
{{- include "core.container.render" . }}
{{- end }}
{{- end }}

{{/*
  Renders topology spread constraints with an auto-injected labelSelector.
  Consumers should define defaults in their chart's values.yaml so they are
  visible and overridable. As a fallback, when the key is absent entirely
  (kindIs "invalid"), two defaults are applied: hostname and zone spreading.
  Set topologySpreadConstraints: [] to disable entirely.
  The labelSelector is injected automatically — do not specify it in values.
  @param  topologySpreadConstraints  {array}  list of { maxSkew, topologyKey, whenUnsatisfiable }
  @return {string}  YAML list of topologySpreadConstraint objects, or empty string
*/}}
{{- define "core.pod.topologySpreadConstraints" -}}
{{- $ctx := . }}
{{- $constraints := .topologySpreadConstraints }}
{{- /* kindIs "invalid": key was not set at all (Go nil) — apply library-level defaults.
       Consumers using helm-templates get these from values.yaml instead. */}}
{{- if kindIs "invalid" $constraints }}
{{- $constraints = list
  (dict "maxSkew" 1 "topologyKey" "kubernetes.io/hostname"      "whenUnsatisfiable" "ScheduleAnyway")
  (dict "maxSkew" 1 "topologyKey" "topology.kubernetes.io/zone" "whenUnsatisfiable" "ScheduleAnyway")
}}
{{- end }}
{{- range $constraints }}
- maxSkew: {{ .maxSkew }}
  topologyKey: {{ .topologyKey }}
  whenUnsatisfiable: {{ .whenUnsatisfiable }}
  labelSelector:
    matchLabels: {{ include "core.general.selectorLabels" $ctx | nindent 6 }}
{{- end }}
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
{{- define "core.pod.volumeClaimTemplates" -}}
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

{{/*
  Renders pod annotations.
  Currently adds a checksum/config annotation when an inline ConfigMap is
  defined, causing pods to roll automatically when the ConfigMap data changes.
  @param  configMap.data  {object}  inline ConfigMap data map (optional)
  @return {string}  YAML key-value annotation block, or empty string
*/}}
{{- define "core.pod.annotations" -}}
{{- if (.configMap).data }}
checksum/config: {{ .configMap.data | toYaml | sha256sum }}
{{- end }}
{{- end }}

{{/*
  Returns the service account name for a pod spec.
  When serviceAccount.create is true, resolves the name via core.serviceaccount.name
  (serviceAccount.name if set, otherwise the chart name) so the pod references
  the ServiceAccount that was just created by the chart.
  When create is false or unset, falls back to serviceAccount.name or "default".
  @param  serviceAccount.name    {string}   explicit service account name (optional)
  @param  serviceAccount.create  {boolean}  whether the chart manages this SA (optional)
  @return {string}  service account name
*/}}
{{- define "core.pod.serviceaccount" -}}
{{- if (.serviceAccount).create }}
{{- include "core.serviceaccount.name" . }}
{{- else }}
{{- (.serviceAccount).name | default "default" }}
{{- end }}
{{- end }}
