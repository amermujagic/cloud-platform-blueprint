resource "aws_iam_role" "karpenter_node_role" {
  name = "${var.cluster_name}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "${var.cluster_name}-karpenter-node-instance-profile"
  role = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name = "${var.cluster_name}-karpenter-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Provisioning"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeImages",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSpotPriceHistory"
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowIAMPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node_role.arn
      }
    ]
  })
}

data "aws_iam_openid_connect_provider" "eks" {
  arn = module.eks.oidc_provider_arn
}

resource "aws_iam_role" "karpenter_controller_role" {
  name = "${var.cluster_name}-karpenter-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_attach" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}