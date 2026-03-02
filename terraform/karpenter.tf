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
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = ""
      }
    })
  ]

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.karpenter_controller_attach
  ]
}

resource "kubernetes_manifest" "karpenter_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default-nodeclass"
    }
    spec = {
      amiFamily = "AL2"

      instanceProfile = aws_iam_instance_profile.karpenter_node_instance_profile.name

      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = {
            "aws:eks:cluster-name" = var.cluster_name
          }
        }
      ]
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "karpenter_amd64_spot" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "amd64-spot"
    }
    spec = {
      disruption = {
        consolidationPolicy = "WhenEmpty"
        expireAfter         = "720h"
      }

      template = {
        spec = {
          nodeClassRef = {
            name = "default-nodeclass"
          }

          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            }
          ]
        }
      }

      limits = {
        cpu = "1000"
      }
    }
  }

  depends_on = [kubernetes_manifest.karpenter_node_class]
}

resource "kubernetes_manifest" "karpenter_arm64_spot" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "arm64-spot"
    }
    spec = {
      disruption = {
        consolidationPolicy = "WhenEmpty"
        expireAfter         = "720h"
      }

      template = {
        spec = {
          nodeClassRef = {
            name = "default-nodeclass"
          }

          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["arm64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            }
          ]
        }
      }

      limits = {
        cpu = "1000"
      }
    }
  }

  depends_on = [kubernetes_manifest.karpenter_node_class]
}