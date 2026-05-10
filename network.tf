
# ################################################################################
# # VPC Network Resources
# ################################################################################

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 6.0"

#   name = local.workspaces[terraform.workspace].name
#   cidr = local.workspaces[terraform.workspace].vpc_cidr

#   azs              = local.workspaces[terraform.workspace].azs
#   public_subnets   = [for k, v in local.workspaces[terraform.workspace].azs : cidrsubnet(local.workspaces[terraform.workspace].vpc_cidr, 8, k)]
#   private_subnets  = [for k, v in local.workspaces[terraform.workspace].azs : cidrsubnet(local.workspaces[terraform.workspace].vpc_cidr, 8, k + 3)]
#   database_subnets = [for k, v in local.workspaces[terraform.workspace].azs : cidrsubnet(local.workspaces[terraform.workspace].vpc_cidr, 8, k + 6)]

#   create_database_subnet_group = true
#   enable_nat_gateway           = true
#   single_nat_gateway           = true

#   tags = local.workspaces[terraform.workspace].tags
# }

