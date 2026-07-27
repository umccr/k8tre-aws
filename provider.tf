terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  required_version = ">= 1.15.0"

  # Bootstrapping: Create the bucket using the ./bootstrap directory
  # Must match aws_s3_bucket.bucket in bootstrap/backend.tf
  backend "s3" {
    bucket       = "tfstate-k8tre-dev-ff5e2f01a9f253fc"
    key          = "tfstate/dev/k8tre-dev"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "umccr-org:Creator" = "terraform"
      "umccr-org:Product" = "k8tre"
      "umccr-org:Source"  = "https://github.com/umccr/k8tre-aws"
    }
  }
}


provider "kubernetes" {
  alias                  = "k8tre-dev"
  host                   = module.k8tre-eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.k8tre-eks.cluster_ca_certificate)
  token                  = module.k8tre-eks.eks_token
}

# provider "helm" {
#   alias = "k8tre-dev"
#   kubernetes = {
#     host                   = module.k8tre-eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.k8tre-eks.cluster_ca_certificate)
#     token                  = module.k8tre-eks.eks_token
#   }
# }


provider "kubernetes" {
  alias                  = "k8tre-dev-argocd"
  host                   = module.k8tre-argocd-eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.k8tre-argocd-eks.cluster_ca_certificate)
  token                  = module.k8tre-argocd-eks.eks_token
}

provider "helm" {
  alias = "k8tre-dev-argocd"
  kubernetes = {
    host                   = module.k8tre-argocd-eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.k8tre-argocd-eks.cluster_ca_certificate)
    token                  = module.k8tre-argocd-eks.eks_token
  }
}
