resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = kubernetes_namespace.karpenter.metadata[0].name
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "0.37.0"

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller_role.arn
        }
      }

      settings = {
        clusterName     = module.eks.cluster_name
        clusterEndpoint = module.eks.cluster_endpoint
        interruptionQueue = ""
      }
    })
  ]

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.karpenter_controller_attach
  ]
}