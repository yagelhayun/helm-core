{{/*
  * Render volumes from configuration in values.yaml 
    (refer to "core.container.volumeMounts" in _container.tpl)
  * @param volumes
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
  * Render imagePullSecrets from image.pullSecrets or global.image.pullSecrets
  * @param image.pullSecrets
  * @param global.image.pullSecrets
*/}}
{{- define "core.pod.imagePullSecrets" -}}
{{- $pullSecrets := (.image).pullSecrets | default ((.global).image).pullSecrets }}
{{- range $pullSecrets }}
- name: {{ . }}
{{- end }}
{{- end }}

{{/*
  * Renders initContainers by delegating to core.container.render.
  * Pod-level volumes used by init containers must be declared in the root volumes config.
  * @param initContainers - list of init container configs
*/}}
{{- define "core.pod.initContainers" }}
{{- range .initContainers }}
{{- include "core.container.render" . }}
{{- end }}
{{- end }}

{{/*
  * Topology Spread Constraints
*/}}
{{- define "core.pod.topologySpreadConstraints" -}}
- maxSkew: 1
  whenUnsatisfiable: ScheduleAnyway
  labelSelector:
    matchExpressions:
    - key: app.kubernetes.io/name
      operator: In
      values:
      - {{ include "core.general.name" . }}
  topologyKey: topology.kubernetes.io/zone
{{- end }}

{{/*
  * Pod annotations
  * @param data
*/}}
{{- define "core.pod.annotations" -}}
{{- if (.configMap).data }}
checksum/config: {{ .configMap.data | toYaml | sha256sum }}
{{- end }}
{{- end }}
