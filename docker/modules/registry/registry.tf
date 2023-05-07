resource "kubernetes_persistent_volume_v1" "registry-pv-volume" {
  metadata {
    name               = "registry-pv-volume-${local.name_suffix}"
    labels             = {
      "app"            = "${var.resource_tags["project"]}"
    }
  }
  spec {
    capacity           = {
      storage          = "10Gi"
    }
    access_modes       = ["ReadWriteMany"]
    # Need this or K8s (minikube) will try to dynamically create a pv for the pvc
    storage_class_name = "manual"
    persistent_volume_source {
      local {
        path           = "/data/registry-pv-volume/"
      }
    }
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key        = "kubernetes.io/hostname"
            operator   = "In"
            values     = [ "minikube" ]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "registry-pv-claim" {
  metadata {
    name               = "registry-pv-claim-${local.name_suffix}"
    namespace          = kubernetes_namespace_v1.namespace.metadata.0.name
    labels             = {
      "app"            = "${var.resource_tags["project"]}"
    }
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    # Need this or K8s (minikube) will try to dynamically create a pv for the pvc
    storage_class_name = "manual"
    resources {
      requests         = {
        storage        = "9Gi"
      }
    }
  }
}

resource "kubernetes_pod_v1" "docker-registry-pod" {
  metadata {
    name       = "docker-registry-pod-${local.name_suffix}"
    namespace  = kubernetes_namespace_v1.namespace.metadata.0.name
    labels     = {
      "app"    = "${var.resource_tags["project"]}"
    }
  }
  spec {
    container {
      image = "registry:2.6.2"
      name  = "registry"
      env {
        name  = "REGISTRY_AUTH"
        value = "htpasswd"
      }
      env {
        name  = "REGISTRY_AUTH_HTPASSWD_REALM"
        value = "Registry Realm"
      }
      env {
        name  = "REGISTRY_AUTH_HTPASSWD_PATH"
        value = "/auth/htpasswd"
      }
      env {
        name  = "REGISTRY_HTTP_TLS_CERTIFICATE"
        value = "/certs/tls.crt"
      }
      env {
        name  = "REGISTRY_HTTP_TLS_KEY"
        value = "/certs/tls.key"
      }
      # volume_mount {
      #   mount_path = "/var/lib/registry"
      #   name       = "repo-vol"
      # }
      volume_mount {
        mount_path = "/certs"
        name       = "certs-vol"
      }
      volume_mount {
        mount_path = "/auth"
        name       = "auth-vol"
        read_only  = true
      }
    }
    volume {
      name = "repo-vol"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.registry-pv-claim.metadata.0.name
      }
    }
    volume {
      name = "certs-vol"
      secret {
        secret_name = "certs-secret"
      }
    }
    volume {
      name = "auth-vol"
      secret {
        secret_name = "auth-secret"
      }
    }
  }
}

resource "kubernetes_service" "docker-registry-service" {
  metadata {
    name       = "docker-registry-service-${local.name_suffix}"
    namespace  = kubernetes_namespace_v1.namespace.metadata.0.name
    labels     = {
      "app"    = "${var.resource_tags["project"]}"
    }
  }
  spec {
    selector = {
      app    = "${var.resource_tags["project"]}"
    }
    port {
      port        = 5000
      target_port = 5000
    }
  }
}
