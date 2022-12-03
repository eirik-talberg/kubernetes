terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = ">= 2.7.1"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config-k3s-mgmt"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config-k3s-mgmt"
}


resource "helm_release" "argo_cd" {
  name = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  version = "5.8.5"
  chart = "argo-cd"
  namespace = "argocd"
  create_namespace = true
  values = [
    "${file("../argo-cd/values.yaml")}"
  ]
}

resource "kubernetes_secret" "github_key" {
    metadata {
      name = "github-key"
      namespace = "argocd"
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    data = {
      "type" = "git"
      "url" = "git@github.com:eirik-talberg/kubernetes"
      "sshPrivateKey" = "${file("~/.ssh/id_rsa")}"
    }
}

resource "kubernetes_manifest" "mgmt-apps" {
  manifest = {
    "apiVersion" ="argoproj.io/v1alpha1"
    "kind" = "Application"
    metadata = {
      "name" = "mgmt-apps"
      "namespace" = "argocd"
      "finalizers" = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    "spec" = {
      "destination" = {
        "namespace" = "argocd"
        "server": "https://kubernetes.default.svc"
      }
      "project" = "default"
      "source" = {
        "path" = "bootstrapping/argo-cd/clusters/mgmt"
        "repoURL" = "git@github.com:eirik-talberg/kubernetes"
        "targetRevision": "HEAD"
      }
      "syncPolicy" = {
        "automated" = {}
      }
    }
  }
}

provider "kubernetes" {
  alias = "workload"
  config_path = "~/.kube/config-k3s-workload"
}

resource "kubernetes_service_account" "argo-cd" {
  provider = kubernetes.workload
  metadata {
    name = "argo-cd"
  }
}

resource "kubernetes_cluster_role_binding" "argo-cd" {
  provider = kubernetes.workload
  metadata {
    name = "argo-cd"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argo-cd"
    namespace = "default"
  }
}

resource "kubernetes_manifest" "argo-cd-secret" {
  provider = kubernetes.workload
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Secret"
    metadata = {
      "name" = "argo-cd-sa-secret"
      "namespace" = "default"
      "annotations" = {
        "kubernetes.io/service-account.name" = "argo-cd"
      }
    }
    "type" = "kubernetes.io/service-account-token"
  }
}

data "kubernetes_secret" "argo-cd-token-secret" {
  provider = kubernetes.workload
  metadata {
    name = "argo-cd-sa-secret"
    namespace = "default"
  }
}

resource "kubernetes_secret" "workload-cluster" {
  metadata {
    name = "workload-cluster"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }
  data = {
    "name" = "k3s-workload"
    "server" = "https://10.0.69.14:6443"
    "config" =jsonencode( {
      "bearerToken" = "${data.kubernetes_secret.argo-cd-token-secret.data.token}"
      "tlsClientConfig" = {
        "insecure": false,
        "caData": base64encode("${data.kubernetes_secret.argo-cd-token-secret.data["ca.crt"]}")
      }
    })
  }
}

resource "kubernetes_namespace" "namespaces" {
  provider = kubernetes.workload
  for_each = toset(["media", "prod", "staging", "dev"])
  metadata {
    name = each.value
  }
}

resource "kubernetes_manifest" "workload-apps" {
  manifest = {
    "apiVersion" ="argoproj.io/v1alpha1"
    "kind" = "Application"
    metadata = {
      "name" = "workload-apps"
      "namespace" = "argocd"
      "finalizers" = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    "spec" = {
      "destination" = {
        "namespace" = "argocd"
        "server": "https://kubernetes.default.svc"
      }
      "project" = "default"
      "source" = {
        "path" = "bootstrapping/argo-cd/clusters/workload"
        "repoURL" = "git@github.com:eirik-talberg/kubernetes"
        "targetRevision": "HEAD"
      }
      "syncPolicy" = {
        "automated" = {}
      }
    }
  }
}