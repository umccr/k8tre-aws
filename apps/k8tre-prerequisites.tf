
locals {
  crds = {
    gateway = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.1/standard-install.yaml"
    loadbalancer = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/tags/v3.0.0/helm/aws-load-balancer-controller/crds/crds.yaml"
    loadbalancer_gateway = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/tags/v3.0.0/helm/aws-load-balancer-controller/crds/gateway-crds.yaml"
  }
}

data "http" "crds" {
  for_each = local.crds
  url      = each.value
}

locals {
  decoded_manifests = {
    for manifest_type, http_data in data.http.crds :
    manifest_type => provider::kubernetes::manifest_decode_multi(http_data.response_body)
  }
  manifests_no_status = merge([
    for manifest_type, manifests in local.decoded_manifests : {
      for manifest in manifests :
      "${manifest_type}--${manifest.kind}--${manifest.metadata.name}" => {
        for k, v in manifest : k => v if k != "status"
      }
    }
  ]...)
}

resource "kubernetes_manifest" "crds" {
  for_each = local.manifests_no_status
  manifest = each.value
  provider = kubernetes.k8tre-dev
}
