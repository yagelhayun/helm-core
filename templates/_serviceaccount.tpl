{{/*
  Returns the name for a ServiceAccount resource.
  When serviceAccount.name is set, returns that value.
  Otherwise falls back to the chart name, which is the default when
  serviceAccount.create is true and no explicit name is given.
  @param  $                    {object}  Helm root context
  @param  serviceAccount.name  {string}  explicit service account name (optional)
  @return {string}  service account name
*/}}
{{- define "core.serviceaccount.name" -}}
{{- (.serviceAccount).name | default (include "core.general.name" .) }}
{{- end }}
