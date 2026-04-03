{{/*
  Renders the volumes list for a pod spec.
  Supports three volume types: secrets (mounted from a Secret), configMaps
  (mounted from a ConfigMap), and empty (emptyDir). Each type is iterated
  separately and validated against the cluster during live deployments.
  @param  $                              {object}  Helm root context (for cluster lookups)
  @param  volumes.secrets    {object}  map of Secret name → { mountPath, defaultMode?, files? }
  @param  volumes.configMaps {object}  map of ConfigMap name → { mountPath, defaultMode?, files? }
  @param  volumes.empty      {object}  map of volume name → {} (emptyDir)
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
    matchLabels: {{ include "core.common.labels" $ctx | nindent 6 }}
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
