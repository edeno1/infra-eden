terraform {
  cloud {
    organization = "test-eden"

    workspaces {
      name = "test"
    }
  }
}
terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.33.0"  # Unified and updated version constraint
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# Configure the Kubernetes Provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    env = {
      AWS_PROFILE = "default"  # Replace 'default' with your AWS profile if necessary
    }
  }
}

# Configure the Helm Provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      env = {
        AWS_PROFILE = "default"
      }
    }
  }
}

# Configure the Kubectl Provider
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    env = {
      AWS_PROFILE = "default"
    }
  }
}

