terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubectl" {
    host = "https://k3s-mgmt-server-01.g69.io:6443"
}


data "kubectl_file_documents" "argocd_mgmt_apps" {
  content = file("../bootstrapping/argo-cd/mgmt-apps.yaml")
}

resource "kubectl_manifest" "argocd_bootstrapping_mgmt_apps" {
  depends_on = [
    data.kubectl_file_documents.argocd_mgmt_apps
  ]
  count     = length(data.kubectl_file_documents.argocd_mgmt_apps.documents)
  yaml_body = element(data.kubectl_file_documents.argocd_mgmt_apps.documents, count.index)
  override_namespace = "argocd"
}