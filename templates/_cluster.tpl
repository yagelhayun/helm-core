{{/*
  * Checks if the chart is actually being deployed (install/upgrade, excluding --dry-run)
  *
  * Why do we need this?
  *
  * When using the lookup command, it needs access to a k8s cluster. At the time of writing this,
  * running "helm template", "helm install --dry-run" etc. won't actually connect to the cluster,
  * and the lookup command will return an empty map. Therefore, we can only use the lookup command
  * when we are actually running a real deployment.
  * 
  * Why did we implement this check this way?
  *
  * The reason we had to compare the $.Release.Name to this weird "RELEASE-NAME" value is that
  * again, at the time of writing this, $.Release.IsUpgrade / $.Release.IsInstall don't work reliably,
  * so we had to use another method. We figured using another field from $.Release would help
  * since $.Release is only relevant when actually releasing (installing/upgrading) the chart, So
  * we decided to simply use the $.Release.Name field. When you deploy the chart, you provide an
  * actual name for the release, and since the default value is "RELEASE-NAME", by checking this we 
  * can make sure that a release name wasn't supplied and therefore this is probably a test run using
  * "helm template", "helm install --dry-run" etc.
*/}}
{{- define "core.isRealDeployment" -}}
{{- $ := (index . "$") }}
{{- and (ne (upper $.Release.Name) "RELEASE-NAME") (ne (toString ($.Values.global).ignoreLookup) "true") -}}
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
