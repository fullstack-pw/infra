luaScripts:
    extract_trace_id.lua: |
        function extract_trace_id(tag, timestamp, record)
            local log = record["log"]
            
            if type(log) == "string" then
                -- Try to extract trace ID using pattern matching
                local _, _, trace_id = string.find(log, "TraceID=([0-9a-f]+)")
                
                if trace_id then
                    -- Add the trace ID as a new field
                    record["trace_id"] = trace_id
                end
            end
            
            return 1, timestamp, record
        end
config:
  inputs: |
    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On
        Refresh_Interval  10

  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Merge_Log_Key       log_processed
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off
        
    [FILTER]
        Name                record_modifier
        Match               *
        Record              log_format structured
        Record              cluster_name ${CLUSTER}
        
    [FILTER]
        Name                lua
        Match               kube.var.log.containers.trace-demo*
        Script              /fluent-bit/scripts/extract_trace_id.lua
        Call                extract_trace_id

  outputs: |
    [OUTPUT]
        Name                   loki
        Match                  *
        Host                   loki.fullstack.pw
        Port                   443
        TLS                    On
        Labels                 job=fluentbit,cluster=${CLUSTER}
        Label_Keys             $kubernetes['namespace_name'],$kubernetes['pod_name'],$kubernetes['container_name'],$kubernetes['labels']['app']
        Remove_Keys            stream
        Auto_Kubernetes_Labels On
        Line_Format            json