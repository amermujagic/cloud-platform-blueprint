# Cloud Platform Blueprint – Terraform (EKS + Karpenter)

## Overview

This Terraform configuration provisions a production-ready Amazon EKS cluster with:

- Dedicated multi-AZ VPC
- Private worker nodes
- Remote Terraform state (S3 + DynamoDB locking)
- Karpenter for dynamic node provisioning
- Spot instance support
- Multi-architecture support (amd64 & arm64 / Graviton)

The solution demonstrates cost-optimized Kubernetes infrastructure using modern autoscaling capabilities.

---

## Architecture Summary

### Infrastructure Components

- **VPC**
  - 3 Availability Zones
  - Public subnets (for Load Balancers)
  - Private subnets (for worker nodes)
  - Single NAT Gateway (POC cost optimization)

- **EKS Cluster**
  - Managed control plane
  - Public + private API endpoint
  - OIDC enabled (IRSA support)
  - Minimal bootstrap managed node group (on-demand)

- **Karpenter**
  - IRSA-based IAM role
  - EC2NodeClass definition
  - Two NodePools:
    - amd64 Spot
    - arm64 (Graviton) Spot

---

## Security Design

- Worker nodes deployed in **private subnets**
- IRSA used instead of node-wide IAM permissions
- IAM PassRole scoped only to Karpenter node role
- Public endpoint enabled (can be CIDR restricted in production)
- Principle of least privilege enforced

---

## Cost Optimization Strategy

- Spot capacity used for workload nodes
- Node consolidation enabled
- Graviton (ARM) instances used for improved price/performance
- Single NAT Gateway for POC cost reduction

### Production Improvements

- Deploy NAT Gateway per AZ
- Add Spot interruption SQS queue
- Add VPC Flow Logs
- Restrict public API endpoint CIDRs

---

## Repository Structure

```
terraform/
├── versions.tf
├── providers.tf
├── vpc.tf
├── eks.tf
├── iam.tf
├── karpenter.tf
├── outputs.tf
├── examples/
│   ├── amd64-deployment.yaml
│   └── arm64-deployment.yaml
└── README.md
```

---

## Prerequisites

- Terraform ≥ 1.5
- AWS CLI configured
- kubectl installed
- AWS account with sufficient permissions

---

## Remote State Backend

This configuration expects an existing S3 bucket and DynamoDB table for state locking.

### Example bootstrap (manual)

```bash
aws s3api create-bucket \
  --bucket cloud-platform-blueprint-tfstate \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws dynamodb create-table \
  --table-name cloud-platform-blueprint-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

---

## Deployment

Initialize Terraform:

```bash
terraform init
```

If backend resources are not created:

```bash
terraform init -backend=false
```

Validate configuration:

```bash
terraform validate
```

Apply infrastructure:

```bash
terraform apply
```

---

## Configure kubectl

After deployment:

```bash
aws eks update-kubeconfig \
  --region eu-central-1 \
  --name <cluster_name>
```

---

## Testing Multi-Architecture Scheduling

### Deploy amd64 workload

```bash
kubectl apply -f examples/amd64-deployment.yaml
```

### Deploy arm64 (Graviton) workload

```bash
kubectl apply -f examples/arm64-deployment.yaml
```

---

## Verify Node Provisioning

```bash
kubectl get nodes -o wide
```

You should observe:

- amd64 Spot node
- arm64 (Graviton) Spot node

---

## Verify Scheduling

```bash
kubectl describe pod <pod-name>
```

---

## How Multi-Architecture Scheduling Works

When a pod defines:

```yaml
nodeSelector:
  kubernetes.io/arch: arm64
```

Flow:

1. Scheduler cannot find matching node.
2. Pod becomes Pending.
3. Karpenter detects the pending pod.
4. Matching NodePool is selected.
5. EC2 instance is provisioned.
6. Pod is scheduled.

---

## Terraform Outputs

Retrieve outputs:

```bash
terraform output
```

Includes:

- Cluster name
- Cluster endpoint
- Karpenter node role ARN

---

## Cleanup

```bash
terraform destroy
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| IRSA enabled | Least privilege AWS access |
| Bootstrap node group | Required to host Karpenter controller |
| Spot NodePools | Cost optimization |
| Graviton support | Better price/performance |
| Explicit instance families | Controlled provisioning |
| Multi-AZ VPC | High availability |

---

## Assignment Requirements Coverage

- EKS cluster via Terraform
- Dedicated VPC
- Karpenter deployment
- Spot instances
- Graviton (arm64) support
- Example workloads for both architectures