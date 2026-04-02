{{/*
  * Render volumeMounts from configuration in values.yaml
    (refer to "core.pod.volumes" in _common.tpl)
  * @param volumes
*/}}
{{- define "core.container.volumeMounts" -}}
{{- range $typeName, $resources := .volumes }}
{{- range $resourceName, $resourceParams := $resources }}
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
{{- $unitsRegex := "([a-z]|[A-Z])+$" }}
{{- $floatRegex := "^[0-9]+(\\.[0-9]+)?" }}
{{- $cpuAmount := (regexFind $floatRegex ((.resources).cpu | toString)) | float64 }}
{{- $cpuUnit := regexFind $unitsRegex ((.resources).cpu | toString) }}
requests:
  cpu: {{ (printf "%g%s" $cpuAmount $cpuUnit) | squote }}
  memory: {{ (.resources).memory | squote }}
limits:
  cpu: {{ (printf "%g%s" (mulf $cpuAmount ((.resources).limitMultiplier | default 4 | float64)) $cpuUnit) | squote }}
  memory: {{ (.resources).memory | squote }}
{{- end }}

{{/*
  * Renders a probe
  * @param probe
*/}}
{{- define "core.container.probes" }}
{{- $port := .port }}
{{- with .probe }}
{{- with .httpGet }}
httpGet:
  path: {{ .path }}
  port: {{ $port }}
  scheme: {{ .scheme | default "HTTP" }}
{{- end }}
{{- with .exec }}
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
  * Renders a startup probe
*/}}
{{- define "core.container.startupProbe" }}
{{- $probeContext := merge (dict "probe" .probes.startup) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}

{{/*
  * Renders a single container as a list item (- name: ...).
  * Used for the main container, sidecars, and init containers.
  * Falls back to the chart name when .name is not set (main container case).
  * @param name            - container name (optional; defaults to chart name)
  * @param image           - image config
  * @param global.image    - global image fallback
  * @param port            - optional container port number
  * @param portName        - optional port name (default: "http")
  * @param command / args  - optional entrypoint overrides
  * @param envFrom / env   - environment configuration
  * @param volumes         - for volumeMounts
  * @param resources       - cpu / memory / limitMultiplier
  * @param probes          - readiness / liveness / startup
*/}}
{{- define "core.container.render" }}
- name: {{ .name | default (include "core.general.name" .) }}
  image: {{ include "core.container.image" . }}
  {{- if .port }}
  ports:
  - containerPort: {{ .port }}
    name: {{ .portName | default "http" }}
    protocol: TCP
  {{- end }}
  {{- with .command }}
  command: {{ toJson . }}
  {{- end }}
  {{- with .args }}
  args: {{ toJson . }}
  {{- end }}
  {{- with (include "core.container.envFrom" .) }}
  envFrom: {{- . | indent 4 }}
  {{- end }}
  resources: {{- include "core.container.resources" . | indent 4 }}
  {{- with (include "core.container.env" .) }}
  env: {{- . | indent 4 }}
  {{- end }}
  {{- with (include "core.container.volumeMounts" .) }}
  volumeMounts: {{- . | indent 4 }}
  {{- end }}
  {{- if (.probes).readiness }}
  readinessProbe: {{- include "core.container.readinessProbe" . | indent 4 }}
  {{- end }}
  {{- if (.probes).liveness }}
  livenessProbe: {{- include "core.container.livenessProbe" . | indent 4 }}
  {{- end }}
  {{- if (.probes).startup }}
  startupProbe: {{- include "core.container.startupProbe" . | indent 4 }}
  {{- end }}
  imagePullPolicy: {{ (.image).pullPolicy | default ((.global).image).pullPolicy | default "IfNotPresent" }}
{{- end }}

{{/*
  * Renders additional sidecar containers by delegating to core.container.render.
  * Pod-level volumes used by sidecars must be declared in the root volumes config.
  * @param sidecars - list of sidecar container configs
*/}}
{{- define "core.container.sidecars" }}
{{- $ := (index . "$") }}
{{- range .sidecars }}
{{- include "core.container.render" (merge (dict "$" $) .) }}
{{- end }}
{{- end }}

{{/*
  * Render image URL
  * @param image
  * @param global.image
*/}}
{{- define "core.container.image" }}
{{- $imageURL := (.image).url | default ((.global).image).url }}
{{- $imageTag := (.image).tag | default ((.global).image).tag | default "latest" }}
{{- printf "%s:%s" $imageURL $imageTag }}
{{- end }}
