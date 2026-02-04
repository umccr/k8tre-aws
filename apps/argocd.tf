
resource "aws_secretsmanager_secret" "argocd_password" {
  name = "k8tre-argocd-secret"
}

data "aws_secretsmanager_random_password" "argocd_password" {
  password_length = 20
}

resource "aws_secretsmanager_secret_version" "argocd_password" {
  secret_id     = aws_secretsmanager_secret.argocd_password.id
  secret_string = data.aws_secretsmanager_random_password.argocd_password.random_password
}

output "k8tre-argocd-secret" {
  value = aws_secretsmanager_secret.argocd_password.id
}

# https://github.com/argoproj/argo-helm/tree/argo-cd-9.0.5/charts/argo-cd
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "9.0.5"
  namespace  = "argocd"

  set = flatten([
    {
      name  = "global.logging.level"
      value = "debug"
    },
    {
      name  = "configs.params.server.insecure"
      value = "true"
    },
    # https://github.com/argoproj/argo-helm/issues/1817
    {
      name  = "configs.cm.kustomize\\.buildOptions"
      value = "--enable-helm --load-restrictor LoadRestrictionsNone"
    },
    {
      name = "configs.secret.argocdServerAdminPassword"
      value = bcrypt(aws_secretsmanager_secret_version.argocd_password.secret_string)
    },
    {
      name  = "repoServer.volumes[0].name"
      value = "cmp-plugin"
    },
    {
      name  = "repoServer.volumes[0].configMap.name"
      value = "cmp-plugin"
    },
    {
      name  = "repoServer.extraContainers[0].name"
      value = "cmp-kustomize-envsubst"
    },
    {
      name  = "repoServer.extraContainers[0].command[0]"
      value = "/var/run/argocd/argocd-cmp-server"
    },
    {
      name  = "repoServer.extraContainers[0].image"
      value = "quay.io/argoproj/argocd:v3.1.9"
    },
    {
      name  = "repoServer.extraContainers[0].securityContext.runAsNonRoot"
      value = "true"
    },
    {
      name  = "repoServer.extraContainers[0].securityContext.runAsUser"
      value = "999"
    },
    {
      name  = "repoServer.extraContainers[0].securityContext.allowPrivilegeEscalation"
      value = "false"
    },
    {
      name  = "repoServer.extraContainers[0].securityContext.readOnlyRootFilesystem"
      value = "true"
    },
    {
      name  = "repoServer.extraContainers[0].securityContext.capabilities.drop[0]"
      value = "ALL"
    },
    {
      name  = "repoServer.extraContainers[0].securityContext.seccompProfile.type"
      value = "RuntimeDefault"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[0].mountPath"
      value = "/var/run/argocd"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[0].name"
      value = "var-files"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[1].mountPath"
      value = "/home/argocd/cmp-server/plugins"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[1].name"
      value = "plugins"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[2].mountPath"
      value = "/tmp"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[2].name"
      value = "tmp"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[3].mountPath"
      value = "/home/argocd/cmp-server/config/plugin.yaml"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[3].subPath"
      value = "plugin.yaml"
    },
    {
      name  = "repoServer.extraContainers[0].volumeMounts[3].name"
      value = "cmp-plugin"
    },
    var.argocd_load_balancer ? [{
      name  = "server.service.type"
      value = "LoadBalancer"
    }] : [],
  ])

  depends_on = [kubernetes_namespace.argocd, aws_secretsmanager_secret_version.argocd_password]

  provider = helm.k8tre-dev-argocd
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  provider = kubernetes.k8tre-dev-argocd
}

# Add k8tre-dev cluster to ArgoCD
# https://argo-cd.readthedocs.io/en/release-3.1/operator-manual/declarative-setup/#eks
resource "kubernetes_secret" "argocd-cluster-k8tre-dev" {
  metadata {
    name      = "argocd-cluster-${data.aws_eks_cluster.deployment.id}"
    namespace = "argocd"
    labels = merge(
      { "argocd.argoproj.io/secret-type" = "cluster" },
      var.k8tre_cluster_labels
    )
  }
  data = {
    config = jsonencode({
      awsAuthConfig = {
        clusterName = data.aws_eks_cluster.deployment.id
        roleARN     = data.terraform_remote_state.k8tre.outputs.k8tre_eks_access_role
      }
      tlsClientConfig = {
        caData = data.aws_eks_cluster.deployment.certificate_authority[0].data
      }
    })
    name   = data.aws_eks_cluster.deployment.id
    server = data.aws_eks_cluster.deployment.endpoint
  }

  provider = kubernetes.k8tre-dev-argocd
}

# https://github.com/k8tre/k8tre/blob/75e550350427d38b637dffbe6f55124ed323ba70/app_of_apps/root-app-of-apps.yaml
resource "kubernetes_manifest" "argocd_root_app_of_apps" {
  count = var.install_crds ? 1 : 0

  manifest = yamldecode(
    replace(
      replace(
        file("root-app-of-apps.yaml"),
        "main", var.k8tre_github_ref
      ),
      "k8tre/k8tre", var.k8tre_github_repo
    )
  )

  # This is a CRD, so ArgoCD must be deployed first
  depends_on = [helm_release.argocd]

  provider = kubernetes.k8tre-dev-argocd
}

resource "kubernetes_manifest" "argocd_cmp_plugin" {
  count = var.install_crds ? 1 : 0
  manifest = yamldecode(file("cmp-plugin.yaml"))
  depends_on = [helm_release.argocd]
  provider = kubernetes.k8tre-dev-argocd
}
