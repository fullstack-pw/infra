variable "enabled" {
  description = "Enable VirtualService creation"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the VirtualService"
  type        = string
}

variable "namespace" {
  description = "Namespace for the VirtualService"
  type        = string
}

variable "hosts" {
  description = "List of destination hosts (can be DNS names or service names)"
  type        = list(string)
}

variable "gateways" {
  description = "List of gateways to attach to (format: namespace/gateway-name or gateway-name)"
  type        = list(string)
}

variable "service_name" {
  description = "Name of the Kubernetes service (used for simple single-service routing)"
  type        = string
  default     = ""
}

variable "service_port" {
  description = "Port of the Kubernetes service (used for simple single-service routing)"
  type        = number
  default     = 80
}

variable "path" {
  description = "Path prefix for routing (used for simple single-route mode)"
  type        = string
  default     = "/"
}

variable "timeout" {
  description = "Timeout for requests (e.g., '30s', '1m')"
  type        = string
  default     = null
}

variable "retries" {
  description = "Retry policy for failed requests"
  type = object({
    attempts      = number
    perTryTimeout = string
    retryOn       = optional(string)
  })
  default = null
}

variable "cors" {
  description = "CORS policy configuration"
  type = object({
    allowOrigins = list(object({
      exact  = optional(string)
      prefix = optional(string)
      regex  = optional(string)
    }))
    allowMethods     = optional(list(string))
    allowHeaders     = optional(list(string))
    exposeHeaders    = optional(list(string))
    maxAge           = optional(string)
    allowCredentials = optional(bool)
  })
  default = null
}

variable "headers" {
  description = "Header manipulation (request/response)"
  type = object({
    request = optional(object({
      set    = optional(map(string))
      add    = optional(map(string))
      remove = optional(list(string))
    }))
    response = optional(object({
      set    = optional(map(string))
      add    = optional(map(string))
      remove = optional(list(string))
    }))
  })
  default = null
}

variable "rewrite" {
  description = "URI rewrite configuration"
  type = object({
    uri       = optional(string)
    authority = optional(string)
  })
  default = null
}

variable "routes" {
  description = "List of HTTP routes (for advanced multi-route configurations)"
  type = list(object({
    match = optional(list(object({
      uri = optional(object({
        exact  = optional(string)
        prefix = optional(string)
        regex  = optional(string)
      }))
      headers = optional(map(object({
        exact  = optional(string)
        prefix = optional(string)
        regex  = optional(string)
      })))
      queryParams = optional(map(object({
        exact = optional(string)
        regex = optional(string)
      })))
      method = optional(string)
    })))
    route = list(object({
      destination = object({
        host   = string
        port   = optional(object({ number = number }))
        subset = optional(string)
      })
      weight  = optional(number)
      headers = optional(map(any))
    }))
    redirect = optional(object({
      uri          = optional(string)
      authority    = optional(string)
      redirectCode = optional(number)
    }))
    rewrite = optional(object({
      uri       = optional(string)
      authority = optional(string)
    }))
    timeout = optional(string)
    retries = optional(object({
      attempts      = number
      perTryTimeout = string
      retryOn       = optional(string)
    }))
    fault = optional(object({
      delay = optional(object({
        percentage = object({
          value = number
        })
        fixedDelay = string
      }))
      abort = optional(object({
        percentage = object({
          value = number
        })
        httpStatus = number
      }))
    }))
    mirror = optional(object({
      host   = string
      subset = optional(string)
    }))
    cors    = optional(map(any))
    headers = optional(map(any))
  }))
  default = []
}

variable "annotations" {
  description = "Additional annotations for the VirtualService"
  type        = map(string)
  default     = {}
}

variable "default_annotations" {
  description = "Add default annotations (cert-manager)"
  type        = bool
  default     = true
}

variable "cluster_issuer" {
  description = "Name of the cert-manager cluster issuer"
  type        = string
  default     = "letsencrypt-prod"
}

variable "routing_mode" {
  description = "Routing mode: 'http' for HTTP routes only, 'tls' for TLS/TCP routes only, 'tcp' for pure TCP routes, 'both' for http+tls"
  type        = string
  default     = "http"
  validation {
    condition     = contains(["http", "tls", "tcp", "both"], var.routing_mode)
    error_message = "routing_mode must be 'http', 'tls', 'tcp', or 'both'"
  }
}

variable "tls_routes" {
  description = "TLS routes for TCP passthrough (databases, etc.)"
  type = list(object({
    match = list(object({
      port     = number
      sniHosts = optional(list(string))
    }))
    route = list(object({
      destination = object({
        host = string
        port = object({
          number = number
        })
      })
      weight = optional(number)
    }))
  }))
  default = []
}

variable "tcp_routes" {
  description = "TCP routes for pure TCP passthrough (no TLS inspection)"
  type = list(object({
    match = list(object({
      port = number
    }))
    route = list(object({
      destination = object({
        host = string
        port = object({
          number = number
        })
      })
      weight = optional(number)
    }))
  }))
  default = []
}
