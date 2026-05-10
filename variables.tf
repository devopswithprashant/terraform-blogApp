variable "enable_rds_bootstrap_ssm" {
  type        = bool
  description = "After RDS is created, run an SSM document on the bastion to create app DB, roles, and schemas."
  default     = true
}

locals {
  workspace_primary_region_map = {
    prod    = "us-east-2"
    nonprod = "eu-west-1"
    default = "us-east-1"
  }

  workspace_secondary_region_map = {
    prod    = "us-west-1"
    nonprod = "eu-central-1"
    default = "us-west-2"
  }

  region  = lookup(local.workspace_primary_region_map, terraform.workspace, local.workspace_primary_region_map.default)
  region2 = lookup(local.workspace_secondary_region_map, terraform.workspace, local.workspace_secondary_region_map.default)

  workspaces = {
    nonprod = {
      name                  = "dwp-platform-nonprod"
      bastion_host_key_name = "bastion-host-key"

      vpc_cidr = "10.0.0.0/16"
      azs      = slice(data.aws_availability_zones.available.names, 0, 3)

      tags = {
        Name    = "dwp-platform-nonprod"
        Project = "Nonprod DevOps with Prashant Platform"
      }
    }
    prod = {
      name                  = "dwp-platform"
      bastion_host_key_name = "prod-bastion-host-key"

      vpc_cidr = "10.0.0.0/16"
      azs      = slice(data.aws_availability_zones.available.names, 0, 3)

      tags = {
        Name    = "dwp-platform"
        Project = "DevOps with Prashant Platform"
      }
    }
  }
}

# locals {
#   current_workspace = local.workspaces[terraform.workspace]
# }