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

/**
resource "kubernetes_manifest" "common-apps" {
  manifest = {
    "apiVersion" ="argoproj.io/v1alpha1"
    "kind" = "ApplicationSet"
    metadata = {
      "name" = "common-apps"
      "namespace" = "argocd"
    }
    "spec" = {
      "generators" = [
          {
            "matrix" = {
              "generators" = [
                  {
                    "git" = {
                      "repoURL" = "git@github.com:eirik-talberg/kubernetes"
                      "revision" = "HEAD"
                      "directories" = [
                        {
                          "path" = "bootstrapping/argo-cd/common-apps/*"
                        }
                      ]
                    }
                  },
                  {
                    "list"= {
                      "elements" = [
                        {
                          "cluster" = "mgmt"
                          "url" = "https://kubernetes.default.svc"
                          "values" = {
                            "project" = "default"
                          }
                        }
                      ]
                    }
                  }
                ]
              
            }
          }
        ]
      
      "template" = {
        "metadata" = {
          "name" = "{{ .path.basename }}-{{ .name }}"
        }
        "spec" = {
          "project" = "default"
          "source" = {
            "repoURL" = "git@github.com:eirik-talberg/kubernetes"
            "targetRevision" = "HEAD"
            "path" = "{{ .path.path }}"
          }
          "destination" = {
            "server" = "{{ .url }}"
            "namespace" = "{{ .path.basename }}"
          }
        }
      }
    }
  }
}
*/