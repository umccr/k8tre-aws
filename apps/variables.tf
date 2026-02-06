variable "region" {
  type        = string
  default     = "ap-southeast-2"
  description = "AWS region"
}

# Update this to point to your terraform state from ../main.tf
data "terraform_remote_state" "k8tre" {
  backend = "s3"

  config = {
    bucket = "tfstate-k8tre-dev-ff5e2f01a9f253fc"
    key    = "tfstate/dev/k8tre-dev"
    region = var.region
  }
}

variable "k8tre_cluster_labels" {
  type = map(string)
  default = {
    environment     = "dev"
    secret-store    = "kubernetes"
    vendor          = "aws"
    skip-metallb    = "true"
    external-domain = "guardians.umccr.org"
  }
  description = "Argocd labels applied to K8TRE cluster"
}

variable "install_k8tre" {
  type        = bool
  default     = true
  description = "Install K8TRE root app-of-apps"
}

variable "k8tre_github_repo" {
  type        = string
  default     = "umccr/k8tre"
  description = "K8TRE GitHub organisation and repository to install"
}

variable "k8tre_github_ref" {
  type        = string
  default     = "main"
  description = "K8TRE git ref (commit/branch/tag)"
}

variable "argocd_load_balancer" {
  type        = bool
  default     = true
  description = "Whether to set the type to `LoadBalancer` for the argocd service enabling external access"
}

# Cluster where K8TRE wil be deployed
data "aws_eks_cluster" "deployment" {
  name = data.terraform_remote_state.k8tre.outputs.k8tre_cluster_name
}
data "aws_eks_cluster_auth" "deployment" {
  name = data.terraform_remote_state.k8tre.outputs.k8tre_cluster_name
}

# Cluster where ArgoCD is deployed
data "aws_eks_cluster" "argocd" {
  name = data.terraform_remote_state.k8tre.outputs.k8tre_argocd_cluster_name
}
data "aws_eks_cluster_auth" "argocd" {
  name = data.terraform_remote_state.k8tre.outputs.k8tre_argocd_cluster_name
}
