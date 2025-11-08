resource "aws_eks_cluster" "my_eks_cluster" {
  name = local.name

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster_role.arn
  version  = "1.33"

  zonal_shift_config {
    enabled = false
  }

  vpc_config {
    security_group_ids      = [ aws_security_group.eks_additional.id ]
    endpoint_private_access = true
    endpoint_public_access  = false
    subnet_ids = [
      data.aws_subnets.nonprod_blog_subnets.ids[0],
      data.aws_subnets.nonprod_blog_subnets.ids[1],
      data.aws_subnets.nonprod_blog_subnets.ids[2],
    ]
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]

}



resource "aws_iam_role" "cluster_role" {
  name = "${local.name}-eks-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}


# EKS Access Entry for Jump Server Role
resource "aws_eks_access_entry" "jumpserver" {
  cluster_name      = aws_eks_cluster.my_eks_cluster.name
  principal_arn     = aws_iam_role.jumpserver.arn
  type              = "STANDARD"
  kubernetes_groups = []

  depends_on = [ 
    aws_eks_cluster.my_eks_cluster,
    aws_iam_role.jumpserver
  ]
}

# EKS Access Policy for Jump Server (Admin access)
resource "aws_eks_access_policy_association" "jumpserver_admin" {
  cluster_name  = aws_eks_cluster.my_eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.jumpserver.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jumpserver]
}



# Additional Security Group for EKS Cluster - Allow 443 from VPC CIDR
resource "aws_security_group" "eks_additional" {
  name_prefix = "eks-additional-sg"
  description = "Additional security group for EKS cluster - Allow 443 from VPC"
  vpc_id      = data.aws_vpc.nonprod_blog.id

  tags = {
    Name = "eks-additional-sg"
  }
}

# Allow inbound 443 from VPC CIDR (10.0.0.0/8)
resource "aws_security_group_rule" "eks_443_from_vpc" {
  description       = "Allow HTTPS from VPC CIDR 10.0.0.0/8"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]
  security_group_id = aws_security_group.eks_additional.id
}

# Allow all outbound traffic (required for EKS)
resource "aws_security_group_rule" "eks_additional_egress" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_additional.id
}