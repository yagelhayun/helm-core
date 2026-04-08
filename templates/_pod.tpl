{{/*
  Renders the volumes list for a pod spec.
  Supports five volume types: secrets (mounted from a Secret), configMaps
  (mounted from a ConfigMap), emptyDirs (emptyDir), pvcs (referencing an
  existing PVC), and hostPaths (mounting a path from the host node).
  Each type is iterated separately and validated against the cluster during
  live deployments.
  @param  $                       {object}  Helm root context (for cluster lookups)
  @param  volumes.secrets         {object}  map of Secret name → { mountPath, defaultMode?, files? }
  @param  volumes.configMaps      {object}  map of ConfigMap name → { mountPath, defaultMode?, files? }
  @param  volumes.emptyDirs       {object}  map of volume name → { mountPath }
  @param  volumes.pvcs            {object}  map of PVC name → { mountPath, readOnly? }
  @param  volumes.hostPaths       {object}  map of volume name → { hostPath, mountPath, type? }
  @return {string}  YAML list of volume objects, or empty string if no volumes
*/}}
{{- define "core.pod.volumes.base" -}}
{{- $ := (index . "$") }}
{{- $ctx := . }}
{{- $defaultPermissions := 420 }}
{{- with .volumes }}
{{- range $resourceName, $resourceParams := .configMaps }}
{{- if ne $resourceName (include "core.configmap.name" $ctx) }}
{{- $_ := include "core.configmap.get" (dict "$" $ "name" $resourceName) | fromYaml }}
{{- end }}
- name: {{ $resourceName }}
  configMap:
    name: {{ $resourceName }}
    defaultMode: {{ ($resourceParams).defaultMode | default $defaultPermissions }}
{{- end }}
{{- range $resourceName, $resourceParams := .secrets }}
{{- $_ := include "core.secret.get" (dict "$" $ "name" $resourceName) | fromYaml }}
- name: {{ $resourceName }}
  secret:
    secretName: {{ $resourceName }}
    defaultMode: {{ ($resourceParams).defaultMode | default $defaultPermissions }}
{{- end }}
{{- range $resourceName, $_ := .emptyDirs }}
- name: {{ $resourceName }}
  emptyDir: {}
{{- end }}
{{- range $resourceName, $resourceParams := .pvcs }}
{{- $pvc := include "core.pvc.get" (dict "$" $ "name" $resourceName) | fromYaml }}
- name: {{ $resourceName }}
  persistentVolumeClaim:
    claimName: {{ $resourceName }}
    {{- if ($resourceParams).readOnly }}
    readOnly: true
    {{- end }}
{{- end }}
{{- range $resourceName, $resourceParams := .hostPaths }}
- name: {{ $resourceName }}
  hostPath:
    path: {{ $resourceParams.hostPath }}
    {{- with $resourceParams.type }}
    type: {{ . }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  Renders the full volumes list, including an auto-generated entry for the
  inline ConfigMap when configMap.as is "volume".
  @param  $          {object}  Helm root context (for cluster lookups)
  @param  volumes    {object}  volumes config map with keys: secrets, configMaps, emptyDirs, pvcs, hostPaths
  @param  configMap  {object}  inline configMap config; when as: volume, appends a volume entry
  @return {string}  YAML list of volume objects, or empty string if no volumes
*/}}
{{- define "core.pod.volumes" -}}
{{- include "core.pod.volumes.base" . }}
{{- if eq ((.configMap).as) "volume" }}
{{- $cmName := include "core.configmap.name" . }}
{{- if and (.volumes).configMaps (hasKey (.volumes).configMaps $cmName) }}
{{- fail (printf "'%s' is already listed under volumes.configMaps — remove the duplicate entry" $cmName) }}
{{- end }}
- name: {{ $cmName }}
  configMap:
    name: {{ $cmName }}
    defaultMode: 420
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
{{- define "core.pod.initContainers" -}}
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
{{- $defaultConstraints := list
  (dict "maxSkew" 1 "topologyKey" "kubernetes.io/hostname"      "whenUnsatisfiable" "ScheduleAnyway")
  (dict "maxSkew" 1 "topologyKey" "topology.kubernetes.io/zone" "whenUnsatisfiable" "ScheduleAnyway")
}}
{{- $constraints := ternary $defaultConstraints .topologySpreadConstraints (kindIs "invalid" .topologySpreadConstraints) }}
{{- range $constraints }}
- maxSkew: {{ .maxSkew }}
  topologyKey: {{ .topologyKey }}
  whenUnsatisfiable: {{ .whenUnsatisfiable }}
  labelSelector:
    matchLabels: {{ include "core.general.selectorLabels" $ctx | nindent 6 }}
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
  Renders the nodeSelector for a pod spec.
  Simple key-value map used to constrain pods to nodes with matching labels.
  @param  nodeSelector  {object}  map of label key → value
  @return {string}  YAML nodeSelector map, or empty string
*/}}
{{- define "core.pod.nodeSelector" -}}
{{- with .nodeSelector }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
  Renders the tolerations list for a pod spec.
  Allows pods to be scheduled on nodes carrying matching taints.
  @param  tolerations  {array}  list of toleration objects
  @return {string}  YAML tolerations list, or empty string
*/}}
{{- define "core.pod.tolerations" -}}
{{- with .tolerations }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
  Renders the hostAliases list for a pod spec.
  Adds custom entries to /etc/hosts inside all containers of the pod.
  @param  hostAliases  {array}  list of { ip, hostnames[] } objects
  @return {string}  YAML hostAliases list, or empty string
*/}}
{{- define "core.pod.hostAliases" -}}
{{- with .hostAliases }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
  Renders the affinity block for a pod spec using a simplified API.
  Supports nodeAffinity and podAntiAffinity with short-form inputs.
  For nodeAffinity, required and preferred are lists of matchExpression objects.
  All required expressions are AND-ed inside a single nodeSelectorTerm.
  For podAntiAffinity, only topologyKey (and weight for preferred) are needed —
  the labelSelector is auto-injected from core.general.selectorLabels.
  @param  $                                   {object}  Helm root context
  @param  affinity.nodeAffinity.required       {array}   list of { key, operator, values? }
  @param  affinity.nodeAffinity.preferred      {array}   list of { weight, key, operator, values? }
  @param  affinity.podAntiAffinity.required    {array}   list of { topologyKey }
  @param  affinity.podAntiAffinity.preferred   {array}   list of { weight, topologyKey }
  @return {string}  YAML affinity block, or empty string
*/}}
{{- define "core.pod.affinity" -}}
{{- $ctx := . }}
{{- with .affinity }}
{{- with .nodeAffinity }}
nodeAffinity:
{{- if .required }}
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
      - matchExpressions:
        {{- range .required }}
        - key: {{ .key }}
          operator: {{ .operator }}
          {{- if .values }}
          values:
            {{- range .values }}
            - {{ . }}
            {{- end }}
          {{- end }}
        {{- end }}
    {{- end }}
{{- if .preferred }}
  preferredDuringSchedulingIgnoredDuringExecution:
  {{- range .preferred }}
  - weight: {{ .weight }}
    preference:
      matchExpressions:
        - key: {{ .key }}
          operator: {{ .operator }}
          {{- if .values }}
          values:
            {{- range .values }}
            - {{ . }}
            {{- end }}
          {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- with .podAntiAffinity }}
podAntiAffinity:
{{- if .required }}
  requiredDuringSchedulingIgnoredDuringExecution:
  {{- range .required }}
  - topologyKey: {{ .topologyKey }}
    labelSelector:
      matchLabels: {{ include "core.general.selectorLabels" $ctx | nindent 8 }}
  {{- end }}
{{- end }}
{{- if .preferred }}
  preferredDuringSchedulingIgnoredDuringExecution:
  {{- range .preferred }}
  - weight: {{ .weight }}
    podAffinityTerm:
      topologyKey: {{ .topologyKey }}
      labelSelector:
        matchLabels: {{ include "core.general.selectorLabels" $ctx | nindent 10 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  Renders the pod-level securityContext.
  Controls pod-wide security settings such as fsGroup, runAsUser, and sysctls.
  @param  podSecurityContext  {object}  Kubernetes PodSecurityContext fields
  @return {string}  YAML securityContext block, or empty string
*/}}
{{- define "core.pod.securityContext" -}}
{{- with .podSecurityContext }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
  Renders the priorityClassName for a pod spec.
  Validates that the referenced PriorityClass exists in the cluster during live
  deployments. No-ops during helm template, dry-run, or when ignoreLookup is set.
  @param  $                  {object}  Helm root context (for cluster lookup)
  @param  priorityClassName  {string}  name of a PriorityClass resource
  @return {string}  priority class name, or empty string
*/}}
{{- define "core.pod.priorityClassName" -}}
{{- $ := (index . "$") }}
{{- with .priorityClassName }}
{{- $_ := include "core.priorityclass.get" (dict "$" $ "name" .) }}
{{- . }}
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
{{/*
  Returns the terminationGracePeriodSeconds for a pod, defaulting to 30.
  Uses ternary+kindIs to distinguish "not set" (nil) from an explicit 0.
  @param  terminationGracePeriodSeconds  {integer}  seconds to wait after SIGTERM before SIGKILL (optional)
  @return {integer}  terminationGracePeriodSeconds value
*/}}
{{- define "core.pod.terminationGracePeriodSeconds" -}}
{{- ternary 30 (int .terminationGracePeriodSeconds) (kindIs "invalid" .terminationGracePeriodSeconds) }}
{{- end }}

{{- define "core.pod.serviceaccount" -}}
{{- if (.serviceAccount).create }}
{{- include "core.serviceaccount.name" . }}
{{- else }}
{{- (.serviceAccount).name | default "default" }}
{{- end }}
{{- end }}
