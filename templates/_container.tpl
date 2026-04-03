{{/*
  Renders the volumeMounts list for a container.
  Iterates over all volume types (secrets, configMaps, empty) and produces
  one mount entry per volume. When a volume defines a "files" list each file
  gets its own subPath mount under the base mountPath.
  @param  volumes  {object}  volumes config map with keys: secrets, configMaps, empty
  @return {string}  YAML list of volumeMount objects, or empty string if no volumes
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
  Renders envFrom entries for named ConfigMaps and Secrets.
  Internal helper used by core.container.envFrom; does not include the
  inline ConfigMap generated from configMap.data.
  @param  $                   {object}  Helm root context (for cluster lookups)
  @param  envFrom.configMaps  {object}  map of configMap names to include as envFrom
  @param  envFrom.secrets     {object}  map of Secret names to include as envFrom
  @return {string}  YAML list of envFrom entries, or empty string
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
  Renders the full envFrom list, including an auto-generated entry for the
  inline ConfigMap when configMap.data is defined.
  The inline ConfigMap name is resolved via configmapNameCallback if provided,
  otherwise falls back to core.configmap.name.
  @param  $                     {object}   Helm root context
  @param  envFrom               {object}   see core.container.envFrom.base
  @param  configMap.data        {object}   if set, a configMapRef for the inline ConfigMap is appended
  @param  configmapNameCallback {string}   name of a template to call for the inline ConfigMap name (optional)
  @return {string}  YAML list of envFrom entries, or empty string
*/}}
{{- define "core.container.envFrom" -}}
{{ include "core.container.envFrom.base" . }}
{{- if (.configMap).data }}
- configMapRef:
    name: {{ include (.configmapNameCallback | default "core.configmap.name") . }}
{{- end }}
{{- end }}

{{/*
  Renders individual env vars sourced from ConfigMap or Secret keys.
  Unlike envFrom, each variable is mapped to a specific key, and the source
  resource is validated to exist (and contain the key) during live deployments.
  @param  $    {object}  Helm root context (for cluster lookups)
  @param  env  {object}  map with keys "configMaps" and/or "secrets", each a map of
                         resource name → list of {key, variable} pairs
  @return {string}  YAML list of env var objects, or empty string
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
  Renders the resources block (requests and limits) for a container.
  CPU limits are computed as request × limitMultiplier. The multiplier
  defaults to 4 when not specified, giving headroom without setting hard caps.
  Memory limits always equal requests (no multiplier applied).
  @param  resources.cpu             {string|number}  CPU request, e.g. "250m" or 1
  @param  resources.memory          {string}         memory request and limit, e.g. "512Mi"
  @param  resources.limitMultiplier {number}         CPU limit multiplier (default: 4)
  @return {string}  YAML resources block with requests and limits
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
  Renders a single probe spec (httpGet or exec) with timing fields.
  Called by the typed probe helpers below — not intended for direct use.
  @param  probe                  {object}   probe definition from values
  @param  probe.httpGet          {object}   httpGet probe config { path, port, scheme }
  @param  probe.exec             {object}   exec probe config { command }
  @param  probe.failureThreshold {integer}  (default: 3)
  @param  probe.initialDelaySeconds {integer} (default: 40)
  @param  probe.periodSeconds    {integer}  (default: 30)
  @param  probe.successThreshold {integer}  (default: 1)
  @param  probe.timeoutSeconds   {integer}  (default: 20)
  @param  port                   {integer}  container port used when probe.httpGet.port is absent
  @return {string}  YAML probe spec block, or empty string if probe is not set
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
  Renders the readinessProbe block.
  @param  probes.readiness  {object}  probe definition (see core.container.probes)
  @param  port              {integer} container port
  @return {string}  YAML readinessProbe spec, or empty string
*/}}
{{- define "core.container.readinessProbe" }}
{{- $probeContext := merge (dict "probe" .probes.readiness) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}

{{/*
  Renders the livenessProbe block.
  @param  probes.liveness  {object}  probe definition (see core.container.probes)
  @param  port             {integer} container port
  @return {string}  YAML livenessProbe spec, or empty string
*/}}
{{- define "core.container.livenessProbe" }}
{{- $probeContext := merge (dict "probe" .probes.liveness) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}

{{/*
  Renders the startupProbe block.
  @param  probes.startup  {object}  probe definition (see core.container.probes)
  @param  port            {integer} container port
  @return {string}  YAML startupProbe spec, or empty string
*/}}
{{- define "core.container.startupProbe" }}
{{- $probeContext := merge (dict "probe" .probes.startup) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}

{{/*
  Renders a single container as a list item (- name: ...).
  Used for the main container, sidecars, and init containers.
  Falls back to the chart name when .name is not set (main container case).
  @param  $                {object}          Helm root context
  @param  name             {string}          container name (default: chart name)
  @param  image.url        {string}          image repository URL
  @param  image.tag        {string}          image tag (default: "latest")
  @param  image.pullPolicy {string}          pull policy (default: "IfNotPresent")
  @param  global.image     {object}          global image fallback for url, tag, and pullPolicy
  @param  port             {integer}         container port number (optional)
  @param  portName         {string}          port name (default: "http")
  @param  command          {array}           entrypoint override (optional)
  @param  args             {array}           argument override (optional)
  @param  envFrom          {object}          bulk env from ConfigMaps/Secrets (see core.container.envFrom)
  @param  configMap.data   {object}          if set, auto-adds inline ConfigMap to envFrom
  @param  env              {object}          individual env vars from keys (see core.container.env)
  @param  volumes          {object}          volumes config used to derive volumeMounts
  @param  resources        {object}          cpu/memory/limitMultiplier (see core.container.resources)
  @param  probes           {object}          readiness/liveness/startup probe definitions
  @return {string}  YAML container list item starting with "- name:"
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
  Renders additional sidecar containers by delegating to core.container.render.
  Pod-level volumes used by sidecars must be declared in the root volumes config.
  @param  $        {object}  Helm root context
  @param  sidecars {array}   list of container config objects (see core.container.render)
  @return {string}  YAML container list items, or empty string if sidecars is empty
*/}}
{{- define "core.container.sidecars" }}
{{- $ := (index . "$") }}
{{- range .sidecars }}
{{- include "core.container.render" (merge (dict "$" $) .) }}
{{- end }}
{{- end }}

{{/*
  Renders the full image reference as "url:tag".
  Falls back to global.image for both url and tag when not set locally.
  @param  image.url     {string}  image repository URL
  @param  image.tag     {string}  image tag (default: "latest")
  @param  global.image  {object}  global image fallback { url, tag }
  @return {string}  image reference string, e.g. "myrepo/myapp:v1.2.3"
*/}}
{{- define "core.container.image" }}
{{- $imageURL := (.image).url | default ((.global).image).url }}
{{- $imageTag := (.image).tag | default ((.global).image).tag | default "latest" }}
{{- printf "%s:%s" $imageURL $imageTag }}
{{- end }}
