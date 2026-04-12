{{/*
  Fetches a ServiceAccount from the cluster by name.
  No-ops silently when not running against a real cluster (helm template,
  dry-run, or global.ignoreLookup: "true") — see core.isRealDeployment.
  Fails the render if the ServiceAccount does not exist during a live deployment.
  @param  $     {object}  Helm root context
  @param  name  {string}  name of the ServiceAccount to look up
  @return {object}  the ServiceAccount resource as a YAML object, or empty if not a real deployment
*/}}
{{- define "core.serviceaccount.get" -}}
{{- $ := (index . "$") }}
{{- include "core.cluster.getResource" (dict "$" $ "name" .name "type" "ServiceAccount") -}}
{{- end }}

{{/*
  Returns the name for a ServiceAccount resource.
  When serviceAccount.create is true, resolves to serviceAccount.name or the
  release name — the SA the chart is about to create.
  When create is false or unset, falls back to serviceAccount.name or "default".
  @param  serviceAccount.name    {string}   explicit service account name (optional)
  @param  serviceAccount.create  {boolean}  whether the chart manages this SA (optional)
  @return {string}  service account name
*/}}
{{- define "core.serviceaccount.name" -}}
{{- if eq (.serviceAccount).create true }}
{{- (.serviceAccount).name | default (include "core.general.name" .) }}
{{- else }}
{{- (.serviceAccount).name | default "default" }}
{{- end }}
{{- end }}
