

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.19.0"
  namespace  = "kube-system"

  set = [
    {
      name  = "cni.chainingMode"
      value = "aws-cni"
    },
    {
      name  = "cni.exclusive"
      value = "false"
    },
    {
      name  = "enableIPv4Masquerade"
      value = "false"
    },
    {
      name  = "routingMode"
      value = "native"
    },
  ]

  provider = helm.k8tre-dev
}


resource "kubernetes_storage_class" "ebs-gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "kubernetes.io/aws-ebs"
  reclaim_policy      = "Delete"
  parameters = {
    type = "gp3"
  }
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  provider = kubernetes.k8tre-dev
}

data "http" "gateway_api_crd" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.1/standard-install.yaml"
}

locals {
  gateway_api_crd = provider::kubernetes::manifest_decode_multi(data.http.gateway_api_crd.response_body)
  # Status key is not allowed in kubernetes_manifest:
  # https://github.com/hashicorp/terraform-provider-kubernetes/issues/1428
  gateway_api_crd_no_status = [
    for manifest in local.gateway_api_crd : { for k, v in manifest : k => v if k != "status" }
  ]
}

resource "kubernetes_manifest" "gateway_api_crd" {
  for_each = {
    for manifest in local.gateway_api_crd_no_status:
      "${manifest.kind}--${manifest.metadata.name}" => manifest
  }
  manifest = each.value
  provider = kubernetes.k8tre-dev
}

data "http" "loadbalancer_crd" {
  url      = "https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.0.0/helm/aws-load-balancer-controller/crds/crds.yaml"
}

resource "kubernetes_manifest" "loadbalancer_crd" {
  manifest = data.http.loadbalancer_crd.response_body
  provider = kubernetes.k8tre-dev
}

data "http" "loadbalancer_gateway_crd" {
  url      = "https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.0.0/helm/aws-load-balancer-controller/crds/gateway-crds.yaml"
}

resource "kubernetes_manifest" "loadbalancer_gateway_crd" {
  manifest = data.http.loadbalancer_gateway_crd.response_body
  provider = kubernetes.k8tre-dev
}
