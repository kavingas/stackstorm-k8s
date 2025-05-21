# Reference - https://git.corp.adobe.com/adobe-platform/k8s-logging-reference/blob/master/fluent-bit-reference.yaml
{{- define "fluent-bit.sidecar.container" -}}
  {{- if $.Values.observability.fluentd.enabled }}
- name: fluent-bit
  # Latest tags are available at https://docs.fluentbit.io/manual/installation/docker
  image: {{ .Values.observability.fluentd.image }}
  imagePullPolicy: IfNotPresent
  # You may need to tune resource requests/limits based on the volume of
  # logs produced by your application
  resources:
    limits:
      cpu: {{ .Values.observability.fluentd.resources.limits.cpu }}
      memory: {{ .Values.observability.fluentd.resources.limits.memory }}
    requests:
      cpu: {{ .Values.observability.fluentd.resources.requests.cpu }}
      memory: {{ .Values.observability.fluentd.resources.requests.memory }}
  ports:
    - containerPort: 2020 # metrics endpoint is ${POD_IP}:2020/api/v1/metrics/prometheus
  volumeMounts:
    # DO NOT CHANGE ANY VOLUME NAMES OR MOUNT PATHS or logging will break
    # The volume where logs are delivered bt the Docker logging driver
    - name: logging-volume
      mountPath: /logging-volume
      mountPropagation: HostToContainer
      # The volume where fluentd stores persistent data
    - name: fluent-data
      mountPath: /var/fluent-bit
      # Mounts the below config map
    - name: fluent-bit-config
      mountPath: /fluent-bit/etc/fluent-bit.conf
      subPath: fluent-bit.conf
    - name: fluent-bit-parsers-config
      mountPath: /fluent-bit/etc/parsers.conf
      subPath: parsers.conf
  env:
    # Memory limit that the file tail plugin can use when appending data to the Engine
    - name: TAIL_BUF_LIMIT
      value: {{ .Values.observability.fluentd.tailBufferLimit }}
      # If you have a custom sourcetype configured with the Splunk team, indicate it below
      # Otherwise, you can specify one of the built in sourcetypes from
      # https://docs.splunk.com/Documentation/Splunk/7.2.0/Data/Listofpretrainedsourcetypes
    - name: SPLUNK_SOURCETYPE
      value: {{ .Values.observability.splunk.sourceType }}
      # The destination index for your logs
    - name: SPLUNK_INDEX
      value: {{ .Values.observability.splunk.index }}
      # Your Splunk HEC authorization token (this should be converted to a secret)
    - name: SPLUNK_TOKEN
      valueFrom:
        secretKeyRef:
          name: {{ .Release.Name }}-splunk-token
          key: splunk_token
      # The destination Splunk host
      # Refer to https://wiki.corp.adobe.com/display/CoreServicesTeam/CST+Splunk+HTTP+Event+Collector
      # to determine the Adobe HTTP Event Collector Endpoint host you should use.
    - name: SPLUNK_HOST
      value: {{ .Values.observability.splunk.hecServer }}
      # The destination Splunk port (usually 443)
    - name: SPLUNK_PORT
      value: {{ .Values.observability.splunk.hecPort | quote }}
      # TLS for sending to CST and CloudTech Splunk HEC should be 'On'
    - name: SPLUNK_TLS
      value: {{ .Values.observability.splunk.tls | quote }}
      # TLS verification should be 'On'
    - name: SPLUNK_TLS_VERIFY
      value: {{ .Values.observability.splunk.tlsVerify | quote }}
      # Change this only if you need to modify the data format (this is rare)
      # https://docs.fluentbit.io/manual/output/splunk#data-format
    - name: LOG_LEVEL
      value: {{ .Values.observability.splunk.logLevel | quote }}
    - name: ROTATE_WAIT
      value: "60"
    - name: REFRESH_INTERVAL
      value: "1"
    - name: LOG_PATH
      value: /logging-volume/*.log
    - name: SPLUNK_SEND_RAW
      value: {{ .Values.observability.splunk.rawDataFormat | quote }}
      # Following fields are used in the Fluent config to enrich Splunk
      # events with Kubernetes metadata
    - name: POD_UID_FLUENT_BIT
      valueFrom:
        fieldRef:
          fieldPath: metadata.uid
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: NODE_IP
      valueFrom:
        fieldRef:
          fieldPath: status.hostIP
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: LOG_PARSER
      value: "docker"
    - name: CLUSTER_NAME
      value: {{ .Values.cluster.name }}
    - name: ENVIRONMENT_NAME
      value: {{ .Values.cluster.environment }}
    - name: APP_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.labels['app.kubernetes.io/name']
  lifecycle:
    preStop:
      exec:
        command:
        - sh
        - -c
        - sleep 70
  startupProbe:
    failureThreshold: 3
    httpGet:
      path: /api/v1/health
      port: 2020
      scheme: HTTP
    initialDelaySeconds: 5
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 1
  terminationMessagePath: /dev/termination-log
  terminationMessagePolicy: File
  {{- end }}
{{- end -}}

{{- define "fluent-bit.sidecar.volumes" -}}
{{- if $.Values.observability.fluentd.enabled }}
- name: logging-volume
  emptyDir: {}
- name: fluent-data
  emptyDir: {}
- name: fluent-bit-config
  configMap:
    name: {{ .Release.Name }}-fluentd-conf
    defaultMode: 420
- name: fluent-bit-parsers-config
  configMap:
    name: {{ .Release.Name }}-fluentd-parser-conf
    defaultMode: 420
  {{- end -}}
{{- end -}}