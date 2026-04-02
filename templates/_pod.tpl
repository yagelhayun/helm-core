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
  * @param dynatrace
*/}}
{{- define "core.pod.annotations" -}}
{{- if (.configMap).data }}
checksum/config: {{ .configMap.data | toYaml | sha256sum }}
{{- end }}
{{- end }}
