```
##
## Global configuration for dynamic sidecars
## These sidecars can be selectively applied to specific services or all services
##
global:
  # Dynamic sidecar configuration
  # Each sidecar can be enabled/disabled and targeted to specific services
  sidecars:
    # Example: Datadog agent sidecar
    datadog-agent:
      enabled: false
      # Services to attach this sidecar to. Use "all" for all services, or specify service names
      # Valid service names: st2auth, st2api, st2stream, st2web, st2rulesengine, st2timersengine, 
      # st2workflowengine, st2scheduler, st2notifier, st2sensorcontainer, st2actionrunner, 
      # st2garbagecollector, st2client, st2chatops
      services: ["all"]  # or ["st2api", "st2actionrunner"] for specific services
      image:
        repository: datadog/agent
        tag: latest
      imagePullPolicy: IfNotPresent
      env:
        - name: DD_API_KEY
          valueFrom:
            secretKeyRef:
              name: datadog-secret
              key: api-key
        - name: DD_SITE
          value: "datadoghq.com"
        - name: DD_LOGS_ENABLED
          value: "true"
        - name: DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL
          value: "true"
        - name: DD_CONTAINER_EXCLUDE
          value: "name:datadog-agent"
      volumeMounts:
        - name: dockersocket
          mountPath: /var/run/docker.sock
          readOnly: true
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: cgroup
          mountPath: /host/sys/fs/cgroup
          readOnly: true
      volumes:
        dockersocket:
          hostPath:
            path: /var/run/docker.sock
        proc:
          hostPath:
            path: /proc
        cgroup:
          hostPath:
            path: /sys/fs/cgroup
      resources:
        limits:
          cpu: 200m
          memory: 256Mi
        requests:
          cpu: 100m
          memory: 128Mi
      securityContext:
        runAsUser: 0
    
    # Example: Prometheus node exporter sidecar
    node-exporter:
      enabled: false
      services: ["st2actionrunner"]  # Only on action runners
      image:
        repository: prom/node-exporter
        tag: latest
      imagePullPolicy: IfNotPresent
      ports:
        - name: metrics
          containerPort: 9100
          protocol: TCP
      args:
        - '--path.procfs=/host/proc'
        - '--path.sysfs=/host/sys'
        - '--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+)($|/)'
      volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
        proc:
          hostPath:
            path: /proc
        sys:
          hostPath:
            path: /sys
      resources:
        limits:
          cpu: 100m
          memory: 100Mi
        requests:
          cpu: 50m
          memory: 50Mi
    
    # Example: Custom logging sidecar
    log-forwarder:
      enabled: false
      services: ["st2api", "st2actionrunner"]  # Only on specific services
      image:
        repository: fluent/fluent-bit
        tag: 1.9.3
      imagePullPolicy: IfNotPresent
      env:
        - name: FLUENT_CONF
          value: fluent-bit.conf
        - name: FLUENT_OPT
          value: ""
      volumeMounts:
        - name: config
          mountPath: /fluent-bit/etc/fluent-bit.conf
          subPath: fluent-bit.conf
        - name: varlog
          mountPath: /var/log
      volumes:
        config:
          configMap:
            name: fluent-bit-config
        varlog:
          emptyDir: {}
      resources:
        limits:
          cpu: 100m
          memory: 128Mi
        requests:
          cpu: 50m
          memory: 64Mi
```