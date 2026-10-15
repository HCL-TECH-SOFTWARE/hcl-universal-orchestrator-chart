{{/*
Expand the name of the chart.
*/}}
{{- define "agenticbuilder.name" -}}
{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "agenticbuilder.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "agenticbuilder.runner.list" -}}
{{- $myList := list "test" "prod" -}}
{{ toJson $myList }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "agenticbuilder.labels" -}}
helm.sh/chart: {{ include "agenticbuilder.chart" . }}
{{ include "agenticbuilder.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "agenticbuilder.selectorLabels" -}}
app.kubernetes.io/name: {{ include "agenticbuilder.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "agenticbuilder.fullname" -}}
{{- if .Values.fullNameOverride }}
{{- .Values.fullNameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $releaseName := default .Release.Name .Values.nameOverride }}
{{- if contains $releaseName .Release.Name }}
{{- printf "%s-agentic" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s-agentic" .Release.Name $releaseName | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "uno.fullname" -}}
{{- $name := default .Release.Name .Values.nameOverride -}}
{{- printf "%s"  $name | trunc 42 | trimSuffix "-" -}}
{{- end -}}


{{- define "agenticbuilder.selectorLabels.backend" -}}
{{- $root := index . 0 -}}
{{- $container := index . 1 -}}
{{- include "agenticbuilder.selectorLabels" $root }}
name: {{ include "agenticbuilder.fullname" $root }}-{{ $container.name }}
track: {{ $root.Values.track }}
tier: backend
{{- end }}

{{- define "agenticbuilder.selectorLabels.frontend" -}}
{{- $root := index . 0 -}}
{{- $container := index . 1 -}}
{{  include "agenticbuilder.selectorLabels" $root }}
name: {{ include "agenticbuilder.fullname" $root }}-{{ $container.name }}
track: {{ $root.Values.track }}
tier: frontend
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "agenticbuilder.serviceAccountName" -}}
{{- if .Values.global.serviceAccountName }}
serviceAccountName: {{ tpl .Values.global.serviceAccountName .}}
{{- else if .Values.serviceAccount.name }}
serviceAccountName: {{ tpl .Values.serviceAccount.name  .}}
{{- end }}
{{- end }}

{{/*
Create image name as "repository-name:tag".
*/}}
{{- define "agenticbuilder.image" -}}
{{- $root := index . 0 -}}
{{- $container := index . 1 -}}
{{- $img := $container.imageName | trim -}}
{{- $last := last (splitList "/" $img) -}}
{{- $hasTag := contains ":" $last -}}
{{- $hasDigest := contains "@" $img -}}

{{- $dict := dict "globalRegistry" "" -}}
{{- if eq $root.Values.global.hclImageRegistry "hclcr.io/sofy" -}}
  {{- $_ := set $dict "globalRegistry" "hclcr.io/uno" -}}
{{- else if eq $root.Values.global.hclImageRegistry "hclcr.io" -}}
  {{- $_ := set $dict "globalRegistry" "hclcr.io/uno" -}}
{{- else if eq $root.Values.global.hclImageRegistry "gcr.io/blackjack-209019" -}}
  {{- $_ := set $dict "globalRegistry" "gcr.io/blackjack-209019/services/uno" -}}
{{- else if $root.Values.global.hclImageRegistry -}}
  {{- $_ := set $dict "globalRegistry" $root.Values.global.hclImageRegistry -}}
{{- end }}
{{- $globalRegistry := $dict.globalRegistry -}}

{{- if or $hasTag $hasDigest -}}
image: "{{ $img }}"
{{- else -}}
  {{- if $globalRegistry -}}
     {{- if $container.image -}}
image: "{{ $globalRegistry }}/{{ $container.imageName }}:{{ default $root.Values.image.tag $container.image.tag }}"
      {{- else -}}
image: "{{  $globalRegistry }}/{{ $container.imageName }}:{{ $root.Values.image.tag }}"
    {{- end -}}  
  {{- else if $container.image -}}
image: "{{ default $root.Values.image.repository $container.image.repository }}/{{ $container.imageName }}:{{ default $root.Values.image.tag $container.image.tag }}"
  {{- else -}}
image: "{{ $root.Values.image.repository }}/{{ $container.imageName }}:{{ $root.Values.image.tag }}"
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create image pull policy.
*/}}
{{- define "agenticbuilder.imagePullPolicy" -}}
{{- $root := index . 0 -}}
{{- $container := index . 1 -}}
{{- $pullPolicy := "" -}}
{{- if and $container $container.image -}} 
{{- $pullPolicy = default $root.Values.image.imagePullPolicy $container.image.imagePullPolicy -}} 
{{- else if $root.Values.image -}}
{{- $pullPolicy = $root.Values.image.imagePullPolicy -}}
{{- else -}}
{{- $pullPolicy = "Always" -}}
{{- end -}}
imagePullPolicy: {{ $pullPolicy }}
{{- end -}}

{{- define "agenticbuilder.microservices.list" -}}
{{- $myList := list "ams" "executor-manager" "credential-manager" "executor" "ui" "cm" -}}
{{ toJson $myList }}
{{- end -}}

{{/*
Create the probe check for the liveness and readiness.
*/}}
{{- define "agenticbuilder.probe" -}}
readinessProbe:
  httpGet:
    path: /ready
    port: port-{{ .port }}
    scheme: HTTPS
  initialDelaySeconds: 15
  periodSeconds: 5
  failureThreshold: 40
  timeoutSeconds: 5
livenessProbe:
  httpGet:
    path: /live
    port: port-{{ .port }}
    scheme: HTTPS
  initialDelaySeconds: 60
  periodSeconds: 10
  failureThreshold: 2
  timeoutSeconds: 5
{{- end}}

{{/*
Return "true" when the autoscaler (HPA) is enabled for a given service, otherwise empty string.
Usage: include "agenticbuilder.autoscaler.enabled" (list $root $serviceAutoscalerValues)
  - $root                  : the root context (.)
  - $serviceAutoscalerValues : the .autoscaler block for the specific service (may be nil)
Precedence: service-level enabled (if non-nil) > common-level enabled > false
*/}}
{{- define "agenticbuilder.autoscaler.enabled" -}}
{{- $root := index . 0 -}}
{{- $svcAutoscaler := index . 1 -}}
{{- $enabled := false -}}
{{- if and $root.Values.common $root.Values.common.autoscaler (hasKey $root.Values.common.autoscaler "enabled") -}}
  {{- $enabled = $root.Values.common.autoscaler.enabled -}}
{{- end -}}
{{- if and $svcAutoscaler (hasKey $svcAutoscaler "enabled") (ne $svcAutoscaler.enabled nil) -}}
  {{- $enabled = $svcAutoscaler.enabled -}}
{{- end -}}
{{- if $enabled -}}true{{- end -}}
{{- end -}}

{{/*
Return "true" when PodDisruptionBudget is enabled for a given service, otherwise empty string.
Usage: include "agenticbuilder.pdb.enabled" (list $root $servicePdbValues)
  - $root            : the root context (.)
  - $servicePdbValues: the .podDisruptionBudget block for the specific service (may be nil)
Precedence: service-level enabled (if non-nil) > common-level enabled > false
*/}}
{{- define "agenticbuilder.pdb.enabled" -}}
{{- $root := index . 0 -}}
{{- $svcPdb := index . 1 -}}
{{- $enabled := false -}}
{{- if and $root.Values.common $root.Values.common.podDisruptionBudget (hasKey $root.Values.common.podDisruptionBudget "enabled") -}}
  {{- $enabled = $root.Values.common.podDisruptionBudget.enabled -}}
{{- end -}}
{{- if and $svcPdb (hasKey $svcPdb "enabled") (ne $svcPdb.enabled nil) -}}
  {{- $enabled = $svcPdb.enabled -}}
{{- end -}}
{{- if $enabled -}}true{{- end -}}
{{- end -}}

{{/*
Return the resolved multitenancy-enabled value as a string ("true" or "false").
Precedence: common.config.enableMultitenancy (if non-nil) > global.enableMultitenant > false
Usage: include "agenticbuilder.multitenancy.enabled" .
*/}}
{{- define "agenticbuilder.multitenancy.enabled" -}}
{{- $enabled := .Values.global.enableMultitenant | default false -}}
{{- printf "%v" $enabled -}}
{{- end -}}

{{/*
Define the resources if found on the container values
*/}}
{{- define "agenticbuilder.resources" -}}
{{- $root := index . 0 -}}
{{- $serviceName := index . 1 -}}
{{- $service := index . 2 -}}
{{- $resources := coalesce $service.resources $root.Values.common.resources -}}
{{- $limits := coalesce $resources.limits $resources.limit -}}
{{- $requests := coalesce $resources.requests $resources.requested -}}
{{- if $resources -}}
resources:
  {{- if $limits }}
  limits: {{ include "agenticbuilder.resource.check" $limits | indent 6}}
  {{- end -}}
  {{- if $requests }}
  requests: {{ include "agenticbuilder.resource.check" $requests | indent 6}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "agenticbuilder.resource.check" -}}
{{- if .cpu }}
cpu: {{ .cpu }}
{{- end }}
{{- if .memory}}
memory: {{ .memory }}
{{- end }}

{{- end }}

{{/*
Define the resources if found on the container values
*/}}
{{- define "agenticbuilder.metrics" -}}
{{- if .hpa.metrics }}
  metrics:
  {{- if .hpa.metrics.cpu }}
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .hpa.metrics.cpu.targetAverageUtilization }}
  {{- end }}
  {{- if .hpa.metrics.memory }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .hpa.metrics.memory.targetAverageUtilization }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.exists.value" -}}
{{- $root := index . 0 -}}
{{- $base := index . 1 -}}
{{- $baseParts := splitList "." $base -}}
{{- $parent := $baseParts | initial -}}
{{- $parentMap := $root.Values -}}
{{- range $parent -}}
  {{- $parentMap = index $parentMap . }}
{{- end }}
{{- $key := last $baseParts -}}
{{- if and (hasKey $parentMap $key) (index $parentMap $key) (ne (toString (index $parentMap $key)) "") }}
true
{{- end }}
{{- end -}}

{{- define "agenticbuilder.get.value" -}}
{{- $root := index . 0 -}}
{{- $base := index . 1 -}}
{{- $baseParts := splitList "." $base -}}
{{- $parent := $baseParts | initial -}}
{{- $parentMap := $root.Values -}}
{{- range $parent }}
  {{- $parentMap = index $parentMap . }}
{{- end }}
{{- $key := last $baseParts -}}
{{- index $parentMap $key -}}
{{- end -}}


{{- define "agenticbuilder.jwt.cert.name" -}}
{{ $fullname := include "agenticbuilder.fullname" . }}
{{- printf "%s-%s"  $fullname "ab-jwt" -}}
{{- end -}}


{{- define "agenticbuilder.cert.name" -}}
{{- if .Values.certificates.certSecretName -}}
{{- tpl .Values.certificates.certSecretName . -}}
{{- else -}}
{{ $fullname := include "agenticbuilder.fullname" . }}
{{- printf "%s-%s"  $fullname "certificates-secret" -}}
{{- end -}}
{{- end -}}

{{- define "agenticbuilder.cert.issuer" -}}
{{- if .Values.certificates.issuerName -}}
{{- tpl .Values.certificates.issuerName . -}}
{{- else -}}
{{ $fullname := include "agenticbuilder.fullname" . }}
{{- printf "%s-%s"  $fullname "agentic-ca-issuer" -}}
{{- end -}}
{{- end -}}

{{- define "agenticbuilder.ca.secret.name" -}}
{{- if .Values.certificates.caPairSecretName -}}
{{- tpl  .Values.certificates.caPairSecretName . | quote }}
{{- else -}}
{{ $fullname := include "agenticbuilder.fullname" . }}
{{- printf "%s-%s"  $fullname "selfsigned-ca" -}}
{{- end -}}
{{- end -}}

{{- define "agenticbuilder.root.ca.name" -}}
{{ $fullname := include "agenticbuilder.fullname" . }}
{{- printf "%s-%s"  $fullname "root-ca" -}}
{{- end -}}

{{- define "agenticbuilder.apikey" -}}
{{- if .Values.global.cloudCredentials -}}
{{ .Values.global.cloudCredentials.gcp | b64enc | quote }}
{{- else -}}
{{ .Values.config.gcp_key | b64enc | quote }}
{{- end -}}
{{- end -}}

{{- define "agenticbuilder.env.valueOrSecret" -}}
{{- $root := index . 0 -}}
{{- $envName := index . 1 -}}
{{- $base := index . 2 -}}
{{- $defaultKey := "" -}}
{{- if gt (len .) 3 }}
  {{- $defaultKey = index . 3 -}}
{{- end }}
{{- $baseParts := splitList "." $base -}}
{{- $parentPath := join "." ($baseParts | initial) -}}
{{- $secretField := printf "%sSecretName" (last $baseParts) -}}
{{- $secretKeyField := printf "%sSecretKey" (last $baseParts) -}}
{{- $secretFieldPath := printf "%s.%s" $parentPath $secretField -}}
{{- $secretKeyFieldPath := printf "%s.%s" $parentPath $secretKeyField -}}
{{- $secretKeyValue := $defaultKey | trim -}}
{{- if include "agenticbuilder.exists.value" (list $root $secretFieldPath) }}
{{- if (include "agenticbuilder.exists.value" (list $root $secretKeyFieldPath))}}
  {{- $secretKeyValue = include "agenticbuilder.get.value" (list $root $secretKeyFieldPath) -}}
{{- else if not $secretKeyValue -}}
    {{- fail (printf "Error: SecretKey field '%s' is missing in values and no default key provided. Please make sure to fill '%s'" $secretKeyFieldPath $secretKeyFieldPath ) -}}
{{- end }}
- name: {{ $envName }}
  valueFrom:
    secretKeyRef:
      name: {{ tpl (include "agenticbuilder.get.value" (list $root $secretFieldPath)) $root | quote }}
      key: {{ tpl $secretKeyValue $root | quote }}
{{- else if include "agenticbuilder.exists.value" (list $root $base) }}
- name: {{ $envName }}
  value: {{ tpl (include "agenticbuilder.get.value" (list $root $base)) $root | quote }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.exists.valueOrSecret" -}}
{{- $root := index . 0 -}}
{{- $base := index . 1 -}}
{{- $baseParts := splitList "." $base -}}
{{- $parentPath := join "." ($baseParts | initial) -}}
{{- $secretField := printf "%sSecretName" (last $baseParts) -}}
{{- $secretKeyField := printf "%sSecretKey" (last $baseParts) -}}
{{- $secretFieldPath := printf "%s.%s" $parentPath $secretField -}}
{{- $secretKeyFieldPath := printf "%s.%s" $parentPath $secretKeyField -}}
{{- if include "agenticbuilder.exists.value" (list $root $secretFieldPath) }}
true
{{- else if include "agenticbuilder.exists.value" (list $root $base) }}
true
{{- end }}
{{- end -}}

{{- define "agenticbuilder.mergestring.underscore" -}}
{{- $result := "" -}}
{{- $string1 :=  index . 0 -}}
{{- $string2 :=  index . 1 -}}
{{- if and $string1 $string2 -}}
{{- $result = printf "%s_%s" $string1 $string2 -}}
{{- else if $string1 -}}
{{- $result = $string1 -}}
{{- else if $string2 -}}
{{- $result = $string2 -}}
{{- end -}}
{{- $result -}}
{{- end -}}

{{- define "agenticbuilder.env.commonssl" -}}
{{- $root := index . 0 -}}
{{- $envPrefix := index . 1 -}}
{{- $base := index . 2 -}}
{{- $folder := index . 3 -}}
{{- $certName := (or $envPrefix "cert") -}}
{{- $caName := (or $envPrefix "ca") -}}
{{- $certField := printf "%s.cert" $base -}}
{{- if (include "agenticbuilder.exists.valueOrSecret" (list $root $certField )) }}
{{- $envName := upper ( include "agenticbuilder.mergestring.underscore" (list $envPrefix "CERT_PATH")) }}
- name: {{ $envName }}
  value: {{ printf "%s/tls.crt" $folder }}
{{- end }}
{{- $keyField := printf "%s.certKey" $base -}}
{{- if (include "agenticbuilder.exists.valueOrSecret" (list $root $keyField )) }}
{{- $envName := upper ( include "agenticbuilder.mergestring.underscore" (list $envPrefix "CERT_KEY_PATH")) }}
- name: {{ $envName }}
  value: {{ printf "%s/tls.key" $folder  }}
{{- end }}
{{- $certKeyPassword := printf "%s.certKeyPassword" $base -}}
{{- if include "agenticbuilder.exists.value" (list $root $certKeyPassword) }}
{{- $envName := upper ( include "agenticbuilder.mergestring.underscore" (list $envPrefix "CERT_KEY_PASSWORD")) }}
- name: {{ $envName }}
  value: {{ tpl (include "agenticbuilder.get.value" (list $root $certKeyPassword)) $root }}
{{- end }}
{{- $certCaField := printf "%s.caCert" $base -}}
{{- if (include "agenticbuilder.exists.valueOrSecret" (list $root $certCaField )) }}
{{- $envName := upper ( include "agenticbuilder.mergestring.underscore" (list $envPrefix "CA_CERT_PATH")) }}
- name: {{ $envName }}
  value: {{ printf "%s/certCA.crt" $folder }}
{{- end }}
{{- $caField := printf "%s.ca" $base -}}
{{- if (include "agenticbuilder.exists.valueOrSecret" (list $root $caField )) }}
{{- $envName := upper ( include "agenticbuilder.mergestring.underscore" (list $envPrefix "CA_PATH")) }}
- name: {{ $envName }}
  value: {{ printf "%s/ca.crt" $folder }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.env.postgres.password" -}}
{{- if or ( .Values.common.postgres.postgresPassword) (and ( .Values.common.postgres.postgresPasswordSecretName) ( .Values.common.postgres.postgresPasswordSecretKey)) }}
{{ include "agenticbuilder.env.valueOrSecret" (list . "POSTGRES_PASSWORD" "common.postgres.postgresPassword") }}
{{- else }}
- name: POSTGRES_PASSWORD
  valueFrom: 
    secretKeyRef:
      name: {{ printf "%s-postgres-password" .Release.Name | trunc 63 | trimSuffix "-" }}
      key: postgres-password
{{- end }}
{{ include "agenticbuilder.postgres.database.url.env" . }}
{{- end -}}

{{- define "agenticbuilder.init.postgres.certificate.env" -}}
- name: POSTGRES_SSLMODE
  value: {{ tpl .Values.common.postgres.ssl.sslMode . | default "prefer" | quote }}
{{- if (include "agenticbuilder.exists.valueOrSecret" (list . "common.postgres.ssl.ca")) }}
- name: POSTGRES_SSLROOTCERT
  value: "/security/postgres/ca.crt"
{{- end }}
{{- if (include "agenticbuilder.exists.valueOrSecret" (list . "common.postgres.ssl.cert")) }}
- name: POSTGRES_SSLCERT
  value: "/security/postgres/tls.crt"
{{- end }}
{{- if (include "agenticbuilder.exists.valueOrSecret" (list . "common.postgres.ssl.certKey")) }}
- name: POSTGRES_SSLKEY
  value: "/security/postgres/tls.key"
{{- end }}
{{- end -}}

{{- define "agenticbuilder.env.postgres.adminpassword" -}}
{{- include "agenticbuilder.env.valueOrSecret" (list . "POSTGRES_ADMIN_USER" "common.postgres.postgresAdminUser") }}
{{ include "agenticbuilder.env.valueOrSecret" (list . "POSTGRES_ADMIN_PASSWORD" "common.postgres.postgresAdminPassword") }}
- name: POSTGRES_ADMIN_SESSION_DB
  value: {{ tpl (.Values.common.postgres.postgresAdminSessionDB | default "postgres") . | quote }}
{{- end -}}

{{- define "agenticbuilder.env.valkey.password" -}}
{{- if .Values.common.valkey.valkeyPasswordSecret }}
- name: VALKEY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ tpl .Values.common.valkey.valkeyPasswordSecret . }}
      key: {{ tpl .Values.common.valkey.valkeyPasswordSecretKey . }}
{{- else if .Values.common.valkey.valkeyPassword }}
- name: VALKEY_PASSWORD
  value: {{ tpl .Values.common.valkey.valkeyPassword . | quote }}
{{- end }}
{{- end -}}

{{/* Generate the name of the deployment */}}
{{- define "agenticbuilder.rag.name" -}}
{{- printf "%s-%s" .Release.Name .Values.rag.app.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "agenticbuilder.pull.secret" -}}
{{- $secrets := list -}}

{{- if .Values.global.hclImagePullSecret }}
{{- $secrets = append $secrets (tpl .Values.global.hclImagePullSecret .) -}}
{{- end }}

{{- if .Values.additionalPullSecret }}
{{- $secrets = append $secrets (tpl .Values.additionalPullSecret .) -}}
{{- end }}

{{- $secrets = append $secrets (printf "sa-%s" .Release.Namespace) -}}
{{- $secrets = append $secrets "sa-uno" -}}

{{- $unique := uniq $secrets -}}
imagePullSecrets:
{{- range $unique }}
  - name: {{ . }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.postgres.client.volume" -}}
- name: postgres-client-certs
  secret:
{{- if .Values.common.postgres.clientCertificateSecret }}
    secretName: {{ tpl .Values.common.postgres.clientCertificateSecret . | quote }}
{{- else -}}
    {{ $fullname := include "agenticbuilder.fullname" . }}
    secretName: {{ $fullname }}-postgres-client-certificate
{{- end }}
    defaultMode: 0640
{{- end -}}

{{- define "agenticbuilder.postgres.initContainer" -}}
{{- if .Values.common.postgres.initDatabases -}}
initContainers:
  - name: init-wait-for-postgres
    image: {{ tpl .Values.image.init.busybox . | default "busybox:latest" | quote }}
    env:
      - name: POSTGRES_HOST
        value: {{ tpl .Values.common.postgres.postgresService . | quote }}
      - name: POSTGRES_PORT
        value: {{ tpl .Values.common.postgres.postgresPort . | quote }}
    command: ['sh', '-c', 'until nc -z "$POSTGRES_HOST" "$POSTGRES_PORT"; do echo waiting for $POSTGRES_HOST:$POSTGRES_PORT; sleep 30; done;']
  - name: init-create-postgres-user
    image: {{ tpl .Values.image.init.postgres . | default "postgres:latest" | quote }}
    volumeMounts:
{{- include "agenticbuilder.commonssl.volumeMounts.postgres" . | nindent 4 }}
    env:
{{- include "agenticbuilder.env.postgres.adminpassword" . | nindent 6 }}
{{- include "agenticbuilder.env.postgres.password" . | nindent 6 }}
{{- include "agenticbuilder.init.postgres.certificate.env" . | nindent 6 }}
{{- include "agenticbuilder.postgres.envs.common" . | nindent 6 }}
    command:
      - sh
      - -c
      - |
        set -e
        if ! PGPORT=$POSTGRES_PORT PGPASSWORD=$POSTGRES_ADMIN_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_ADMIN_USER" -d "$POSTGRES_ADMIN_SESSION_DB" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$POSTGRES_USER'" | grep -q 1; then
          PGPORT=$POSTGRES_PORT PGPASSWORD=$POSTGRES_ADMIN_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_ADMIN_USER" -d "$POSTGRES_ADMIN_SESSION_DB" -c "CREATE USER \"$POSTGRES_USER\" WITH PASSWORD '$POSTGRES_PASSWORD';"
        else
          echo "User $POSTGRES_USER already exists"
        fi
        # Always grant membership so the admin can act on behalf of the user in the next step
        PGPORT=$POSTGRES_PORT PGPASSWORD=$POSTGRES_ADMIN_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_ADMIN_USER" -d "$POSTGRES_ADMIN_SESSION_DB" -c "GRANT \"$POSTGRES_USER\" TO \"$POSTGRES_ADMIN_USER\";"
  - name: init-create-postgres-db
    image: {{ tpl .Values.image.init.postgres . | default "postgres:latest" | quote }}
    volumeMounts:
{{- include "agenticbuilder.commonssl.volumeMounts.postgres" . | nindent 4 }}
    env:
{{- include "agenticbuilder.init.postgres.certificate.env" . | nindent 6 }}
{{- include "agenticbuilder.env.postgres.adminpassword" . | nindent 6 }}
{{- include "agenticbuilder.postgres.envs.common" . | nindent 6 }}
    command:
      - sh
      - -c
      - |
        set -e
        if ! PGPORT=$POSTGRES_PORT PGPASSWORD=$POSTGRES_ADMIN_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_ADMIN_USER" -d "$POSTGRES_ADMIN_SESSION_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DB'" | grep -q 1; then
          PGPORT=$POSTGRES_PORT PGPASSWORD=$POSTGRES_ADMIN_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_ADMIN_USER" -d "$POSTGRES_ADMIN_SESSION_DB" -c "CREATE DATABASE $POSTGRES_DB WITH OWNER \"$POSTGRES_USER\" ENCODING=UTF8 TEMPLATE=template0;"
        else
          echo "Database $POSTGRES_DB already exists with this user $POSTGRES_USER"
        fi
        # Enforce the correct owner every time
        PGPORT=$POSTGRES_PORT PGPASSWORD=$POSTGRES_ADMIN_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_ADMIN_USER" -d "$POSTGRES_ADMIN_SESSION_DB" -c "ALTER DATABASE $POSTGRES_DB OWNER TO \"$POSTGRES_USER\";"
        # Enable pgvector extension 
        PGPORT=$POSTGRES_PORT PGPASSWORD=$POSTGRES_ADMIN_PASSWORD psql "host=$POSTGRES_HOST port=$POSTGRES_PORT user=$POSTGRES_ADMIN_USER dbname=$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS vector;"
      {{- end }}
{{- end -}}

{{- define "agenticbuilder.replace.dash.percentdash" -}}
{{- replace "-" "%-" . -}}
{{- end -}}

{{- define "agenticbuilder.hclauthorization.env" -}}
{{- $root := . -}}
{{- $unofullname := include "uno.fullname" . -}}
{{- $ctx := merge (dict "unofullname" $unofullname) . -}}
{{- if .Values.authorization.certs }}
{{- $idx := 0 -}}
{{- range $key, $value := .Values.authorization.certs }}
- name: {{ $key }}
  value: /authcert/{{ tpl (lower $value) $ctx }}_{{ $idx }}.crt
{{- $idx = add $idx 1 }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.hclauthorization.volume.mount" -}}
{{- $root := . }}
{{- $unofullname := include "uno.fullname" . -}}
{{- $ctx := merge (dict "unofullname" $unofullname) . -}}
{{- if .Values.authorization.certs }}
{{- $idx := 0 -}}
{{- range $key, $value := .Values.authorization.certs }}
- name: {{ tpl (lower $value) $ctx }}-cert-volume
  mountPath: /authcert/{{ tpl (lower $value) $ctx }}_{{ $idx }}.crt
  subPath: {{ tpl (lower $value) $ctx }}.crt
  readOnly: true
{{- $idx = add $idx 1 -}}
{{- end }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.hclauthorization.volume" -}}
{{- if .Values.authorization.certs }}
{{- $root := . -}}
{{- $unofullname := include "uno.fullname" . -}}
{{- $ctx := merge (dict "unofullname" $unofullname) . -}}
{{- $seen := dict -}}
{{- range $key, $value := .Values.authorization.certs -}}
{{- $val := tpl (lower $value) $ctx -}}
{{- if not (hasKey $seen $val) }}
- name: {{ $val }}-cert-volume
  secret:
    defaultMode: 0644
    secretName: {{ tpl (toString $value) $ctx | quote }}
    items:
    - key: tls.crt
      path: {{ $val }}.crt
{{- $_ := set $seen $val true -}}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.additionalCAs.volume" -}}
{{- range .Values.common.truststore.agenticAdditionalCASecrets }}
  {{- if kindIs "string" . }}
- name: {{ tpl . $ }}-cert-volume
  secret:
    defaultMode: 0664
    secretName: {{ tpl . $ | quote }}
    items:
    - key: ca.crt
      path: {{ tpl . $ }}.crt
  {{- else if and (hasKey . "secretName") (hasKey . "secretKey") }}
- name: {{ tpl .secretName $ }}-cert-volume
  secret:
    defaultMode: 0664
    secretName: {{ tpl .secretName $ | quote }}
    items:
    - key: {{ tpl .secretKey $ | quote }}
      path: {{ tpl .secretKey $ }}.crt
  {{- else }}
    {{- fail "agenticAdditionalCASecrets must be a string or an object with secretName and secretKey" }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.jwt.volume" -}}
{{ $certName := include "agenticbuilder.jwt.cert.name" . }}
- name: {{ tpl $certName . }}-cert-vol
  secret:
    defaultMode: 0664
    secretName: {{ tpl $certName . | quote }}
{{- end -}}

{{- define "agenticbuilder.jwt.volumeMounts" -}}
{{ $certName := include "agenticbuilder.jwt.cert.name" . }}
- name: {{ tpl $certName .}}-cert-vol
  mountPath: /jwt/agenticbuilder/
{{- end -}}

{{- define "agenticbuilder.additionalCAs.volumeMounts" -}}
{{- range .Values.common.truststore.agenticAdditionalCASecrets }}
- name: {{ tpl . $}}-cert-volume
  mountPath: /ca/{{ tpl . $ }}
{{- end }}
{{- end -}}

{{- define "agenticbuilder.otel.volume" -}}
{{- if or ( eq (tpl .Values.telemetry.telemetryTraceInsecure .) "false")  (eq (tpl .Values.telemetry.telemetryMetricInsecure .) "false") }}
- name: {{ tpl .Values.telemetry.telemetryExporterCertificate . }}-cert-volume
  secret:
    defaultMode: 0664
    secretName: {{ tpl .Values.telemetry.telemetryExporterCertificate . | quote }}
    items:
    - key: tls.crt
      path: {{ tpl .Values.telemetry.telemetryExporterCertificate .  }}.crt
{{- end }}
{{- end -}}

{{- define "agenticbuilder.otel.volumeMounts" -}}
{{- if or ( eq (tpl .Values.telemetry.telemetryTraceInsecure .) "false")  (eq (tpl .Values.telemetry.telemetryMetricInsecure .) "false") }}
- name: {{ tpl .Values.telemetry.telemetryExporterCertificate . }}-cert-volume
  mountPath: /ca/otel/
{{- end }}
{{- end -}}

{{- define "agenticbuilder.postgres.database.url.env" -}}
- name: DATABASE_URL
  value: "postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@{{ tpl .Values.common.postgres.postgresService . }}:$(POSTGRES_PORT)/{{ tpl .Values.common.postgres.postgresDB . }}"
{{- end -}}

{{- define "agenticbuilder.postgres.database.adminurl.env" -}}
- name: DATABASE_URL
  value: "postgresql://$(ADMIN_POSTGRES_USER):$(ADMIN_POSTGRES_PASSWORD)@{{ tpl .Values.common.postgres.postgresService . }}:$(POSTGRES_PORT)/{{ tpl .Values.common.postgres.postgresDB . }}"
{{- end -}}

{{- define "agenticbuilder.postgres.envs.common" -}}
{{- include "agenticbuilder.env.valueOrSecret" (list . "POSTGRES_HOST" "common.postgres.postgresService") }}
{{- include "agenticbuilder.env.valueOrSecret" (list . "POSTGRES_PORT" "common.postgres.postgresPort") }}
{{- include "agenticbuilder.env.valueOrSecret" (list . "POSTGRES_DB" "common.postgres.postgresDB") }}
{{- include "agenticbuilder.env.valueOrSecret" (list . "POSTGRES_USER" "common.postgres.postgresUser") }}
{{- end -}}

{{/*
agenticbuilder.commonssl.hasSecretSources
Args: (list $root $base)
  $root - the top-level template context (".")
  $base - dotted values path to the ssl block, e.g. "common.postgres.ssl"
Returns "true" iff at least one of <base>.certSecretName, <base>.certKeySecretName,
<base>.certCaSecretName, <base>.caSecretName exists (per agenticbuilder.exists.value).
Returns a truly empty string (no whitespace) otherwise, since a whitespace-only
return is truthy in a Helm "if" and would silently re-enable an empty volume/mount.
*/}}
{{- define "agenticbuilder.commonssl.hasSecretSources" -}}
{{- $root := index . 0 -}}
{{- $base := index . 1 -}}
{{- $certField := printf "%s.certSecretName" $base -}}
{{- $certKeyField := printf "%s.certKeySecretName" $base -}}
{{- $certCaField := printf "%s.certCaSecretName" $base -}}
{{- $caField := printf "%s.caSecretName" $base -}}
{{- if or (include "agenticbuilder.exists.value" (list $root $certField)) (include "agenticbuilder.exists.value" (list $root $certKeyField)) (include "agenticbuilder.exists.value" (list $root $certCaField)) (include "agenticbuilder.exists.value" (list $root $caField)) -}}
{{- "true" -}}
{{- end -}}
{{- end -}}

{{/*
agenticbuilder.commonssl.projected.source
Args: (list $root $base $fieldName $defaultKey $path $mode)
  $root       - the top-level template context (".")
  $base       - dotted values path to the ssl block, e.g. "common.postgres.ssl"
  $fieldName  - one of "cert", "certKey", "certCa", "ca" — matched against
                <base>.<fieldName>SecretName / <base>.<fieldName>SecretKey
  $defaultKey - secret key to use when <base>.<fieldName>SecretKey is unset
  $path       - in-container filename to project the key to (tls.crt, tls.key,
                certCA.crt, ca.crt) — must stay byte-identical across contexts
  $mode       - file mode for this projected item (octal, e.g. 0644, 0600)
Emits one `- secret:` entry under `projected.sources` only when
<base>.<fieldName>SecretName exists; emits nothing otherwise, so the caller can
safely include the result unconditionally for each of the four fields.
*/}}
{{- define "agenticbuilder.commonssl.projected.source" -}}
{{- $root := index . 0 -}}
{{- $base := index . 1 -}}
{{- $fieldName := index . 2 -}}
{{- $defaultKey := index . 3 -}}
{{- $path := index . 4 -}}
{{- $mode := index . 5 -}}
{{- $secretFieldPath := printf "%s.%sSecretName" $base $fieldName -}}
{{- $secretKeyFieldPath := printf "%s.%sSecretKey" $base $fieldName -}}
{{- if (include "agenticbuilder.exists.value" (list $root $secretFieldPath)) }}
{{- $secretKeyValue := $defaultKey | trim -}}
{{- if (include "agenticbuilder.exists.value" (list $root $secretKeyFieldPath)) -}}
  {{- $secretKeyValue = include "agenticbuilder.get.value" (list $root $secretKeyFieldPath) | trim -}}
{{- end }}
- secret:
    name: {{ tpl (include "agenticbuilder.get.value" (list $root $secretFieldPath)) $root | quote }}
    items:
    - key: {{ tpl $secretKeyValue $root | quote }}
      path: {{ $path }}
      mode: {{ $mode }}
{{- end }}
{{- end -}}

{{/*
agenticbuilder.commonssl.volumeMounts
Args: (list $root $volumeNamePrefix $base $folder)
Emits exactly one mount for the <prefix>-common-ssl-volume projected volume
(see agenticbuilder.commonssl.volume) at $folder as a plain directory mount —
no subPath — so the four files it contains (tls.crt, tls.key, certCA.crt,
ca.crt) are kept current by the kubelet on cert-manager renewal. Guarded by
the same hasSecretSources predicate as agenticbuilder.commonssl.volume so the
two never disagree on whether this context renders.
*/}}
{{- define "agenticbuilder.commonssl.volumeMounts" -}}
{{- $root := index . 0 -}}
{{- $volumeNamePrefix := index . 1  | lower -}}
{{- $base := index . 2 -}}
{{- $folder := index . 3 -}}
{{- if (include "agenticbuilder.commonssl.hasSecretSources" (list $root $base)) }}
- name: {{ tpl $volumeNamePrefix $root }}-common-ssl-volume
  mountPath: {{ tpl $folder $root }}
  readOnly: true
{{- end }}
{{- end -}}

{{/*
agenticbuilder.commonssl.volume
Args: (list $root $volumeNamePrefix $base)
Emits a single `projected` volume named <prefix>-common-ssl-volume whose
sources are the (up to four) secrets configured for this TLS context, each
contributing its key under the filename the application already expects
(tls.crt, tls.key, certCA.crt, ca.crt) in one directory. Guarded by
agenticbuilder.commonssl.hasSecretSources so it stays in lockstep with
agenticbuilder.commonssl.volumeMounts (both must agree on when the context
renders — see design doc "Emptiness/consistency invariant").
Note: mounted without subPath so cert-manager renewals propagate to disk via
the kubelet's symlink-swap update (unlike subPath bind-mounts, which do not).
*/}}
{{- define "agenticbuilder.commonssl.volume" -}}
{{- $root := index . 0 -}}
{{- $volumeNamePrefix := index . 1  | lower -}}
{{- $base := index . 2 -}}
{{- if (include "agenticbuilder.commonssl.hasSecretSources" (list $root $base)) }}
- name: {{ tpl $volumeNamePrefix $root }}-common-ssl-volume
  projected:
    defaultMode: 0644
    sources:
{{- include "agenticbuilder.commonssl.projected.source" (list $root $base "cert" "tls.crt" "tls.crt" "0644") | indent 4 }}
{{- include "agenticbuilder.commonssl.projected.source" (list $root $base "certKey" "tls.key" "tls.key" "0600") | indent 4 }}
{{- include "agenticbuilder.commonssl.projected.source" (list $root $base "certCa" "ca.crt" "certCA.crt" "0644") | indent 4 }}
{{- include "agenticbuilder.commonssl.projected.source" (list $root $base "ca" "ca.crt" "ca.crt" "0644") | indent 4 }}
{{- end }}
{{- end -}}


{{- define "agenticbuilder.commonssl.volumeMounts.postgres" -}}
{{- include "agenticbuilder.commonssl.volumeMounts" (list . "postgres" "common.postgres.ssl" "/security/postgres") -}}
{{- end -}}

{{- define "agenticbuilder.commonssl.volume.postgres" -}}
{{- include "agenticbuilder.commonssl.volume" (list . "postgres" "common.postgres.ssl") -}}
{{- end -}}

{{- define "agenticbuilder.commonssl.env.postgres" -}}
{{ include "agenticbuilder.env.commonssl" (list . "POSTGRES" "common.postgres.ssl" "/security/postgres") }}
{{- end -}}

{{- define "agenticbuilder.commonssl.volumeMounts.definition" -}}
{{ include "agenticbuilder.commonssl.volumeMounts" (list . "client" "common.ssl" "/security/client") }}
{{ include "agenticbuilder.commonssl.volumeMounts.postgres" . }}
{{ include "agenticbuilder.commonssl.volumeMounts" (list . "valkey" "common.valkey.ssl" "/security/valkey") }}
{{- end -}}

{{- define "agenticbuilder.commonssl.volume.definition" -}}
{{- include "agenticbuilder.commonssl.volume.postgres" . -}}
{{- include "agenticbuilder.commonssl.volume" (list . "client" "common.ssl") -}}
{{- include "agenticbuilder.commonssl.volume" (list . "valkey" "common.valkey.ssl") -}}
{{- end -}}

{{- define "agenticbuilder.commonssl.env.definition" -}}
{{ include "agenticbuilder.env.commonssl" (list . "" "common.ssl" "/security/client") }}
{{ include "agenticbuilder.commonssl.env.postgres" . }}
{{ include "agenticbuilder.env.commonssl" (list . "VALKEY" "common.valkey.ssl" "/security/valkey") }}
{{- end -}}

{{- define "common.postgres.fullname" -}}
{{- printf "%s-pg-db" .Release.Name | trunc 21 | trimSuffix "-" -}}
{{- end -}}

{{/*
Inject standard Kubernetes chart/release metadata as environment variables using the Downward API.
Usage: include "agenticbuilder.k8s.metadata.env" .
Produces:
  K8S_NAMESPACE        — pod's namespace (Downward API)
  K8S_POD_NAME         — pod's name (Downward API)
  K8S_POD_IP           — pod's IP (Downward API)
  K8S_NODE_NAME        — node name (Downward API)
  K8S_RELEASE_NAME     — Helm release name
  K8S_CHART_NAME       — chart name
  K8S_CHART_VERSION    — chart version
  K8S_APP_VERSION      — chart appVersion
*/}}
{{- define "agenticbuilder.k8s.metadata.env" -}}
- name: K8S_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: K8S_POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: K8S_POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: K8S_NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: K8S_RELEASE_NAME
  value: {{ .Release.Name | quote }}
- name: K8S_CHART_NAME
  value: {{ .Chart.Name | quote }}
- name: K8S_CHART_VERSION
  value: {{ .Chart.Version | quote }}
- name: K8S_APP_VERSION
  value: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{- define "agenticbuilder.sofy.env.variables" -}}
{{- if and .Values.global .Values.global.sofySolutionContext }}
- name : SOFY_HOSTNAME
  valueFrom:
    configMapKeyRef:
        name: {{ .Release.Name }}-domain
        key : HOST
{{- end }}
{{- if and .Values.global (.Values.global.sofySolutionContext) }} 
- name: OIDC_SERVER_URL
  value : https://sofy-kc.$(SOFY_HOSTNAME)/auth
{{- else if .Values.authorization.oidcServerURL }}
- name: OIDC_SERVER_URL
  value: {{ tpl .Values.authorization.oidcServerURL .}}
{{- end }}
{{- end -}}