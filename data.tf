# data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

# EKS Cluster Auth
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.my_eks_cluster.name
}

data "aws_key_pair" "jumpserver_key" {
  key_name = local.workspaces[terraform.workspace].bastion_host_key_name
}

data "tls_certificate" "eks" {
  #url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  url = aws_eks_cluster.my_eks_cluster.identity[0].oidc[0].issuer
}

# # Ubuntu AMI data source
# # data "aws_ami" "ubuntu" {
# #   most_recent = true
# #   owners      = ["099720109477"] # Canonical
# #   filter {
# #     name   = "name"
# #     values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-*-server-*"]
# #   }
# #   filter {
# #     name   = "virtualization-type"
# #     values = ["hvm"]
# #   }
# # }
