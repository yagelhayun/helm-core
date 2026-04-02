{{/*
  * Render volumeMounts from configuration in values.yaml
    (refer to "core.pod.volumes" in _common.tpl)
  * @param volumes
*/}}
{{- define "core.container.volumeMounts" -}}
{{- range $typeName, $resources := .volumes }}
{{- if ne $typeName "empty" }}
{{- range $resourceName, $resourceParams := $resources }}
{{- $mountPath := required "Missing mountPath property" $resourceParams.mountPath }}
{{- if ne (typeOf $resourceParams.mountPath) "string" }}
{{- fail "mountPath must be a string" }}
{{- end }}
{{- if $resourceParams.files }}
{{- range $variable := $resourceParams.files }}
- name: {{ $resourceName }}
  mountPath: {{ printf "%s/%s" $resourceParams.mountPath $variable }}
  subPath: {{ $variable }}
{{- end }}
{{- else }}
- name: {{ $resourceName }}
  mountPath: {{ $resourceParams.mountPath }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  * Render envFrom from configuration in values.yaml
  * @param envFrom
*/}}
{{- define "core.container.envFrom.base" -}}
{{- $ := (index . "$") }}
{{- with .envFrom -}}
{{- range $resourceName, $_ := .configMaps }}
- configMapRef:
    name: {{ $resourceName }}
{{- end }}
{{- range $resourceName, $_ := .secrets }}
{{- $secret := include "core.secret.get" (dict "$" $ "name" $resourceName) }}
- secretRef:
    name: {{ $resourceName }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  * Render envFrom and add generated configmap automatically
  * @param envFrom
  * @param configMap
  * @param configmapNameCallback
*/}}
{{- define "core.container.envFrom" -}}
{{ include "core.container.envFrom.base" . }}
{{- if (.configMap).data }}
- configMapRef:
    name: {{ include (.configmapNameCallback | default "core.configmap.name") . }}
{{- end }}
{{- end }}

{{/*
  * Render env
  * This function checks whether the configMaps/secrets exist in the namespace, unlike other functions from the same category (volumes, envFrom).
  * @param env
*/}}
{{- define "core.container.env" -}}
{{- $ := (index . "$") }}
{{- range $resourceType, $resourceMap := .env }}
{{- range $resourceName, $variables := $resourceMap }}
{{- $singularType := trimSuffix "s" $resourceType }}
{{- $getFunctionName := printf "core.%s.get" (lower $singularType) }}
{{- $resource := include $getFunctionName (dict "$" $ "name" $resourceName) | fromYaml }}
{{- $refType := printf "%sKeyRef" $singularType }}
{{- range $variables }}
{{- include "core.cluster.checkIfKeyExists" (dict "$" $ "resource" $resource "key" .key) }}
{{- $variable := required (printf "Resource \"%s\" of type %s with key \"%s\" must include a variable property" $resourceName $singularType .key) .variable }}
{{- if ne (typeOf .variable) "string" }}
{{- fail (printf "Resource \"%s\" of type %s contains a non-string variable \"%v\"" $resourceName $singularType .variable) }}
{{- end }}
- name: {{ .variable }}
  valueFrom:
    {{ $refType }}:
      name: {{ $resourceName }}
      key: {{ .key }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  * Create resources object that .........
  * @param resources
*/}}
{{- define "core.container.resources" -}}
{{- $cpu := required "Missing resources.cpu property" (.resources).cpu }}
{{- $memory := required "Missing resources.memory property" (.resources).memory }}
{{- $unitsRegex := "([a-z]|[A-Z])+$" }}
{{- $floatRegex := "^[0-9]+(\\.[0-9]+)?" }}
{{- $cpuAmount := (regexFind $floatRegex ($cpu | toString)) | float64 }}
{{- $cpuUnit := regexFind $unitsRegex ($cpu | toString) }}
requests:
  cpu: {{ (printf "%g%s" $cpuAmount $cpuUnit) | squote }}
  memory: {{ $memory | squote }}
limits: 
  cpu: {{ (printf "%g%s" (mulf $cpuAmount 4) $cpuUnit) | squote }}
  memory: {{ $memory | squote }}
{{- end }}

{{/*
  * Renders a probe
  * @param probe
*/}}
{{- define "core.container.probes" }}
{{- $port := .port }}
{{- with .probe }}
{{- if and (empty .httpGet) (empty .exec) }}
{{- fail "Missing httpGet or exec" }}
{{- end }}
{{- if and (not (empty .httpGet)) (not (empty .exec)) }}
{{- fail "Cannot define both httpGet and exec" }}
{{- end }}
{{- with .httpGet }}
{{- $port := required "Missing port property" $port }}
{{- $path := required "Missing path property" .path }}
{{- if ne (typeOf $path) "string" }}
{{- fail ".path must be a string" }}
{{- end }}
httpGet:
  path: {{ $path }}
  port: {{ $port }}
  scheme: {{ .scheme | default "HTTP" }}
{{- end }}
{{- with .exec }}
{{- $command := required "Missing command property" .command }}
exec: {{ toYaml .command | nindent 2 }}
{{- end }}
failureThreshold: {{ .failureThreshold | default 3 }}
initialDelaySeconds: {{ .initialDelaySeconds | default 40 }}
periodSeconds: {{ .periodSeconds | default 30 }}
successThreshold: {{ .successThreshold | default 1 }}
timeoutSeconds: {{ .timeoutSeconds | default 20 }}
{{- end }}
{{- end }}

{{/*
  * Renders a readiness probe
*/}}
{{- define "core.container.readinessProbe" }}
{{- $probeContext := merge (dict "probe" .probes.readiness) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}

{{/*
  * Renders a liveness probe
*/}}
{{- define "core.container.livenessProbe" }}
{{- $probeContext := merge (dict "probe" .probes.liveness) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}

{{/*
  * Render image URL
  * @param image
  * @param global.image
*/}}
{{- define "core.container.image" }}
{{- $imageURL := (.image).url | default ((.global).image).url }}
{{- $imageTag := (.image).tag | default ((.global).image).tag | default "latest" }}
{{- $url := required "Missing image url property" $imageURL }}
{{- printf "%s:%s" $imageURL $imageTag }}
{{- end }}
