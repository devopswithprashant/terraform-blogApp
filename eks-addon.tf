# resource "aws_iam_openid_connect_provider" "eks" {
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
#   url             = aws_eks_cluster.my_eks_cluster.identity[0].oidc[0].issuer
# }

# # IAM Role for EBS CSI Driver
# resource "aws_iam_role" "ebs_csi_driver" {
#   name = "${local.workspaces[terraform.workspace].name}-ebs-csi-controller-sa-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = aws_iam_openid_connect_provider.eks.arn
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
#           }
#         }
#       },
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
#   role       = aws_iam_role.ebs_csi_driver.name
# }

# # EKS Add-on (Installs the Driver)
# resource "aws_eks_addon" "ebs_csi" {
#   cluster_name             = aws_eks_cluster.my_eks_cluster.name
#   addon_name               = "aws-ebs-csi-driver"
#   service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
# }


# # Patching/Defining the gp2 StorageClass
# # We use kubernetes_annotations to ensure it's marked as default
# resource "kubernetes_annotations" "gp2_default" {
#   api_version = "storage.k8s.io/v1"
#   kind        = "StorageClass"
#   force       = true

#   metadata {
#     name = "gp2"
#   }

#   annotations = {
#     "storageclass.kubernetes.io/is-default-class" = "true"
#   }

#   depends_on = [aws_eks_addon.ebs_csi]
# }


# # Defining the StorageClass parameters to match your manifest
# # Note: If gp2 already exists, you may need to run `terraform import` 
# # for this resource specifically, or rely on the patch above.
# resource "kubernetes_storage_class" "ebs_csi_gp2" {
#   metadata {
#     name = "gp2"
#   }

#   storage_provisioner    = "ebs.csi.aws.com"
#   volume_binding_mode    = "WaitForFirstConsumer"
#   reclaim_policy         = "Delete"
#   allow_volume_expansion = true

#   parameters = {
#     type   = "gp2"
#     fsType = "ext4"
#   }

#   # This lifecycle block prevents TF from fighting with the annotation patch
#   lifecycle {
#     ignore_changes = [
#       metadata[0].annotations["storageclass.kubernetes.io/is-default-class"]
#     ]
#   }

#   depends_on = [aws_eks_addon.ebs_csi]
# }
