terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "cloud-platform-blueprint-tfstate"
    key            = "eks/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "cloud-platform-blueprint-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}