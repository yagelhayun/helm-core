{{/*
  Returns the name for a CronJob resource.
  Semantic alias for core.general.name — exists so templates stay readable
  when referencing the resource kind explicitly.
  @param  $  {object}  Helm root context
  @return {string}  chart name
*/}}
{{- define "core.cronjob.name" -}}
{{- include "core.general.name" . }}
{{- end }}

{{/*
  Returns the suspend flag for a CronJob, defaulting to false.
  @param  cronJob.suspend  {boolean}  whether to suspend the CronJob (optional)
  @return {boolean}  suspend value
*/}}
{{- define "core.cronjob.suspend" -}}
{{- (.cronJob).suspend | default false }}
{{- end }}

{{/*
  Returns the concurrencyPolicy for a CronJob, defaulting to Forbid.
  @param  cronJob.concurrencyPolicy  {string}  "Allow" | "Forbid" (default) | "Replace"
  @return {string}  concurrencyPolicy value
*/}}
{{- define "core.cronjob.concurrencyPolicy" -}}
{{- (.cronJob).concurrencyPolicy | default "Forbid" }}
{{- end }}

{{/*
  Returns the successfulJobsHistoryLimit for a CronJob, defaulting to 3.
  @param  cronJob.successfulJobsHistory  {integer}  number of successful jobs to retain (optional)
  @return {integer}  successfulJobsHistoryLimit value
*/}}
{{- define "core.cronjob.successfulJobsHistoryLimit" -}}
{{- (.cronJob).successfulJobsHistory | default 3 }}
{{- end }}

{{/*
  Returns the failedJobsHistoryLimit for a CronJob, defaulting to 1.
  @param  cronJob.failedJobsHistory  {integer}  number of failed jobs to retain (optional)
  @return {integer}  failedJobsHistoryLimit value
*/}}
{{- define "core.cronjob.failedJobsHistoryLimit" -}}
{{- (.cronJob).failedJobsHistory | default 1 }}
{{- end }}
