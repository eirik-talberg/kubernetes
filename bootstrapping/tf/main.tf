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
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "argocd" {
    metadata {
      name = "argocd"
    }
}

data "kubectl_file_documents" "argocd" {
    content = file("../argo-cd/install.yaml")
}

resource "kubectl_manifest" "argocd" {
    depends_on = [
      data.kubectl_file_documents.argocd
    ]
    count     = length(data.kubectl_file_documents.argocd.documents)
    yaml_body = element(data.kubectl_file_documents.argocd.documents, count.index)
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