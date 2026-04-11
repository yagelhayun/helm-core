{{/*
  Renders the volumeMounts list for a container.
  Iterates over all volume types (secrets, configMaps, emptyDirs, pvcs, hostPaths) and produces
  one mount entry per volume. When a volume defines a "files" list each file
  gets its own subPath mount under the base mountPath.
  @param  volumes  {object}  volumes config map with keys: secrets, configMaps, emptyDirs, pvcs, hostPaths
  @return {string}  YAML list of volumeMount objects, or empty string if no volumes
*/}}
{{- define "core.container.volumeMounts.base" -}}
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
  Renders the full volumeMounts list, including an auto-generated entry for the
  inline ConfigMap when configMap.as is "volume".
  @param  volumes    {object}  volumes config map with keys: secrets, configMaps, emptyDirs, pvcs, hostPaths
  @param  configMap  {object}  inline configMap config; when as: volume, appends a mount
  @return {string}  YAML list of volumeMount objects, or empty string if no volumes
*/}}
{{- define "core.container.volumeMounts" -}}
{{- include "core.container.volumeMounts.base" . }}
{{- if eq ((.configMap).as) "volume" }}
{{- $cmName := include "core.configmap.name" . }}
{{- if and (.volumes).configMaps (hasKey (.volumes).configMaps $cmName) }}
{{- fail (printf "'%s' is already listed under volumes.configMaps — remove the duplicate entry" $cmName) }}
{{- end }}
- name: {{ $cmName }}
  mountPath: {{ (.configMap).mountPath }}
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
{{- $ctx := . }}
{{- with .envFrom -}}
{{- range $resourceName, $_ := .configMaps }}
{{- if ne $resourceName (include "core.configmap.name" $ctx) }}
{{- $_ := include "core.configmap.get" (dict "$" $ "name" $resourceName) | fromYaml }}
{{- end }}
- configMapRef:
    name: {{ $resourceName }}
{{- end }}
{{- range $resourceName, $_ := .secrets }}
{{- $_ := include "core.secret.get" (dict "$" $ "name" $resourceName) }}
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
{{- if and (.configMap).data (eq ((.configMap).as | default "env") "env") }}
{{- $cmName := include "core.configmap.name" . }}
{{- if and (.envFrom).configMaps (hasKey (.envFrom).configMaps $cmName) }}
{{- fail (printf "'%s' is already listed under envFrom.configMaps — remove the duplicate entry" $cmName) }}
{{- end }}
- configMapRef:
    name: {{ $cmName }}
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
  Resolves the primary port number for probes and other single-port references.
  When primaryPort is set, uses that named entry from the ports map.
  When ports has exactly one entry, auto-detects it.
  When ports has multiple entries and primaryPort is absent, fails the render.
  Returns empty string when no ports are defined (e.g. exec-only workloads).
  @param  ports        {object}  map of port name → portConfig
  @param  primaryPort  {string}  optional name of the primary port
  @return {string}  port number as a string, or empty string
*/}}
{{- define "core.container.primaryPortNumber" -}}
{{- if .ports }}
{{- if .primaryPort }}
{{- (index .ports .primaryPort).port }}
{{- else if gt (len .ports) 1 }}
{{- fail "primaryPort is required when multiple ports are defined" }}
{{- else }}
{{- $firstKey := first (keys .ports | sortAlpha) }}
{{- (index .ports $firstKey).port }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  Renders a single probe spec (httpGet or exec) with timing fields.
  Called by the typed probe helpers below — not intended for direct use.
  @param  probe                  {object}   probe definition from values
  @param  probe.httpGet          {object}   httpGet probe config { path, scheme }
  @param  probe.exec             {object}   exec probe config { command }
  @param  probe.failureThreshold {integer}  (default: 3)
  @param  probe.initialDelaySeconds {integer} (default: 40)
  @param  probe.periodSeconds    {integer}  (default: 30)
  @param  probe.successThreshold {integer}  (default: 1)
  @param  probe.timeoutSeconds   {integer}  (default: 20)
  @param  port                   {integer}  primary port number for httpGet probes
  @return {string}  YAML probe spec block, or empty string if probe is not set
*/}}
{{- define "core.container.probes" -}}
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
{{- define "core.container.readinessProbe" -}}
{{- if (.probes).readiness }}
{{- $probeContext := merge (dict "probe" .probes.readiness) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}
{{- end }}

{{/*
  Renders the livenessProbe block.
  @param  probes.liveness  {object}  probe definition (see core.container.probes)
  @param  port             {integer} container port
  @return {string}  YAML livenessProbe spec, or empty string
*/}}
{{- define "core.container.livenessProbe" -}}
{{- if (.probes).liveness }}
{{- $probeContext := merge (dict "probe" .probes.liveness) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}
{{- end }}

{{/*
  Renders the startupProbe block.
  @param  probes.startup  {object}  probe definition (see core.container.probes)
  @param  port            {integer} container port
  @return {string}  YAML startupProbe spec, or empty string
*/}}
{{- define "core.container.startupProbe" -}}
{{- if (.probes).startup }}
{{- $probeContext := merge (dict "probe" .probes.startup) . }}
{{- include "core.container.probes" $probeContext }}
{{- end }}
{{- end }}

{{/*
  Renders the container-level securityContext.
  Controls per-container security settings such as capabilities, readOnlyRootFilesystem,
  and allowPrivilegeEscalation.
  @param  containerSecurityContext  {object}  Kubernetes SecurityContext fields
  @return {string}  YAML securityContext block, or empty string
*/}}
{{- define "core.container.securityContext" -}}
{{- with .containerSecurityContext }}
{{- toYaml . }}
{{- end }}
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
  @param  ports            {object}          map of port name → { port } (optional)
  @param  primaryPort      {string}          name of the primary port used by probes (optional when single port)
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
  {{- with .ports }}
  ports:
  {{- range $portName, $portConfig := . }}
  - containerPort: {{ $portConfig.port }}
    name: {{ $portName }}
    protocol: TCP
  {{- end }}
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
  {{- $probeCtx := merge (dict "port" (include "core.container.primaryPortNumber" . | trim)) . }}
  {{- with (include "core.container.readinessProbe" $probeCtx) }}
  readinessProbe: {{- . | indent 4 }}
  {{- end }}
  {{- with (include "core.container.livenessProbe" $probeCtx) }}
  livenessProbe: {{- . | indent 4 }}
  {{- end }}
  {{- with (include "core.container.startupProbe" $probeCtx) }}
  startupProbe: {{- . | indent 4 }}
  {{- end }}
  imagePullPolicy: {{ (.image).pullPolicy | default ((.global).image).pullPolicy | default "IfNotPresent" }}
  {{- with (include "core.container.securityContext" .) }}
  securityContext: {{ . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
  Renders additional sidecar containers by delegating to core.container.render.
  Pod-level volumes used by sidecars must be declared in the root volumes config.
  @param  $        {object}  Helm root context
  @param  sidecars {array}   list of container config objects (see core.container.render)
  @return {string}  YAML container list items, or empty string if sidecars is empty
*/}}
{{- define "core.container.sidecars" -}}
{{- $ := (index . "$") }}
{{- range .sidecars }}
{{- include "core.container.render" (merge (dict "$" $) .) }}
{{- end }}
{{- end }}

{{/*
  Renders the full image reference as "[registry/]repository:tag".
  Falls back to global.image for registry, repository, and tag when not set locally.
  @param  image.registry    {string}  optional registry host, e.g. "docker.io", "gcr.io"
  @param  image.repository  {string}  image name/path, e.g. "myrepo/myapp"
  @param  image.tag         {string}  image tag (default: "latest")
  @param  global.image      {object}  global image fallback { registry, repository, tag }
  @return {string}  image reference string, e.g. "gcr.io/myrepo/myapp:v1.2.3"
*/}}
{{- define "core.container.image" -}}
{{- $registry := (.image).registry | default ((.global).image).registry }}
{{- $repository := (.image).repository | default ((.global).image).repository }}
{{- $tag := (.image).tag | default ((.global).image).tag | default "latest" }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}
