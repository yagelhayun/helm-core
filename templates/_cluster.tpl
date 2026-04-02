{{/*
  * Checks if the chart is actually being deployed (install/upgrade, excluding --dry-run)
  *
  * Why do we need this?
  *
  * When using the lookup command, it needs access to a k8s cluster.
  * Running "helm template" or "helm install --dry-run" won't connect to the cluster,
  * so lookup returns an empty map. We can only use lookup during a real deployment.
  *
  * Uses $.Release.IsRender (Helm 3.13+) when available. On older versions it falls back to
  * checking whether the release name is the default "RELEASE-NAME" placeholder used by
  * "helm template". The ignoreLookup global flag can be set to "true" to bypass cluster
  * lookups explicitly (useful in tests and local rendering).
*/}}
{{- define "core.isRealDeployment" -}}
{{- $ := (index . "$") }}
{{- $isRender := or $.Release.IsRender (eq (upper $.Release.Name) "RELEASE-NAME") -}}
{{- and (not $isRender) (ne (toString ($.Values.global).ignoreLookup) "true") -}}
{{- end }}

{{/*
  * Gets a resource from the cluster and fails if it doesn't exist
  *
  * We used "core.isRealDeployment" to make sure the lookup will work.
  * If we can actually connect to the cluster *AND* the resource information returned from lookup
  * is falsey (null/empty), we fail the template.
  *
  * @param name
  * @param type
  * @param version
*/}}
{{- define "core.cluster.getResource" -}}
{{- $ := (index . "$") }}
{{- $isRealDeployment := eq (include "core.isRealDeployment" .) "true" -}}
{{- $resource := (lookup (.version | default "v1") .type $.Release.Namespace .name) -}}

{{- if and $isRealDeployment (not $resource) -}}
  {{- fail (cat .type (.name | squote) "doesn't exist") -}}
{{- end -}}

{{ $resource | toYaml }}
{{- end }}

{{/*
  * Fails if the resource doesnt contain a certain key
  * @param resource
  * @param key
*/}}
{{- define "core.cluster.checkIfKeyExists" -}}
{{- $isRealDeployment := eq (include "core.isRealDeployment" .) "true" -}}
{{- if $isRealDeployment -}}
  {{- if not (index .resource.data .key) -}}
    {{- fail (cat .resource.kind (.resource.metadata.name | squote) "doesn't contain key" (.key | squote)) -}}
  {{- end -}}
{{- end -}}
{{- end }}
