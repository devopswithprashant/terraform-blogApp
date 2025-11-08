# output security_group_id {
#   description = "The newly created EKS Cluster Security Group ID for jumpserver"
#   value       = aws_security_group.jumpserver_sg.id
# }