terraform {
  required_version = ">= 1.11.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    # helm = {
    #   source  = "hashicorp/helm"
    #   version = ">= 2.10"
    # }
  }
}

# Configure the AWS Provider
provider "aws" {
  #region = lookup(local.workspace_region_map, terraform.workspace, local.workspace_region_map.default)
  region = local.region
}

# Configure Kubernetes Provider
provider "kubernetes" {
  host                   = aws_eks_cluster.my_eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.my_eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# # Configure Helm Provider
# provider "helm" {
#   kubernetes {
#     host                   = aws_eks_cluster.my_eks_cluster.endpoint
#     cluster_ca_certificate = base64decode(aws_eks_cluster.my_eks_cluster.certificate_authority[0].data)
#     token                  = data.aws_eks_cluster_auth.cluster.token
#   }
# }

