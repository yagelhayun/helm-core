{{/*
  Returns "true" when Helm is running a real install or upgrade against a live
  cluster, and "false" for dry-runs, helm template, and test renders.

  Why this matters: the lookup function requires a live cluster connection.
  Calling it during helm template or --dry-run returns an empty map, which
  would cause misleading validation failures. This helper gates all cluster
  lookups so they only fire when the result is trustworthy.

  Detection logic (in order):
    1. $.Release.IsRender — set by Helm 3.13+ for all non-live renders.
    2. Release name == "RELEASE-NAME" — the placeholder used by helm template
       on older Helm versions.
    3. global.ignoreLookup: "true" — explicit opt-out, useful in tests and
       local rendering regardless of Helm version.

  @param  $                     {object}  Helm root context
  @param  global.ignoreLookup   {string}  set to "true" to force non-real-deployment mode
  @return {string}  "true" | "false"
*/}}
{{- define "core.isRealDeployment" -}}
{{- $ := (index . "$") }}
{{- $isRender := or $.Release.IsRender (eq (upper $.Release.Name) "RELEASE-NAME") -}}
{{- and (not $isRender) (ne (toString ($.Values.global).ignoreLookup) "true") -}}
{{- end }}

{{/*
  Fetches an arbitrary resource from the cluster and fails if it is missing.
  Skips the lookup (returns empty) when not running against a real cluster.
  Callers receive the resource as a YAML object and can read its fields.
  @param  $        {object}  Helm root context
  @param  name     {string}  resource name
  @param  type     {string}  resource kind, e.g. "Secret", "ConfigMap"
  @param  version  {string}  API version for the lookup (default: "v1")
  @return {string}  YAML-encoded resource object, or empty string during non-live renders
*/}}
{{- define "core.cluster.getResource" -}}
{{- $ := (index . "$") }}
{{- $isRealDeployment := eq (include "core.isRealDeployment" .) "true" -}}
{{- $namespace := ternary .namespace $.Release.Namespace (hasKey . "namespace") -}}
{{- $resource := (lookup (.version | default "v1") .type $namespace .name) -}}

{{- if and $isRealDeployment (not $resource) -}}
  {{- fail (cat .type (.name | squote) "doesn't exist") -}}
{{- end -}}

{{ $resource | toYaml }}
{{- end }}

{{/*
  Validates that a fetched resource contains a specific data key.
  No-ops during non-live renders (helm template, dry-run).
  Fails the render if the key is absent during a live deployment,
  preventing a broken rollout from reaching the cluster.
  @param  $         {object}  Helm root context
  @param  resource  {object}  resource object returned by core.cluster.getResource
  @param  key       {string}  the data key that must exist in resource.data
*/}}
{{- define "core.cluster.checkIfKeyExists" -}}
{{- $isRealDeployment := eq (include "core.isRealDeployment" .) "true" -}}
{{- if $isRealDeployment -}}
  {{- if not (index .resource.data .key) -}}
    {{- fail (cat .resource.kind (.resource.metadata.name | squote) "doesn't contain key" (.key | squote)) -}}
  {{- end -}}
{{- end -}}
{{- end }}
