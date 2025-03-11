{{/*
Expand the name of the chart.
*/}}
{{- define "kdp-infra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-"}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kdp-infra.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kdp-infra.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kdp-infra.labels" -}}
helm.sh/chart: {{ include "kdp-infra.chart" . }}
{{ include "kdp-infra.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kdp-infra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kdp-infra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kdp-infra.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kdp-infra.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- /*
Create the image to use
*/}}
{{- define "kdp-infra.image" -}}
{{- $registry := .Values.image.registry -}}
{{- $tag := ternary (printf ":%s" (.Values.image.tag | default "latest" | toString))  (printf "@%s" .Values.image.digest) (eq .Values.image.digest "") -}}
{{- if eq .Values.image.registry  "" -}}
    {{- printf "%s%s" .Values.image.repository $tag -}}
{{- else }}
    {{- printf "%s/%s%s" .Values.image.registry .Values.image.repository $tag -}}
{{- end -}}
{{- end -}}