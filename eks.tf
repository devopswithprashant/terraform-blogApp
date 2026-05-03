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
    security_group_ids      = [aws_security_group.eks_additional.id]
    endpoint_private_access = true
    endpoint_public_access  = false
    subnet_ids              = module.vpc.private_subnets
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
  vpc_id      = module.vpc.vpc_id

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

resource "aws_eks_node_group" "my_eks_node_group" {
  cluster_name    = aws_eks_cluster.my_eks_cluster.name
  node_group_name = "private-large"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = module.vpc.private_subnets
  ami_type        = "AL2023_ARM_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  instance_types  = ["m6g.large"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.node_group_role-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_group_role-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_role-AmazonEKS_CNI_Policy,
  ]
}



resource "aws_iam_role" "node_group_role" {
  name = "${local.name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "node_group_role-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_role-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_role-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.name
}
