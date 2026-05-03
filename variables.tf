variable "enable_rds_bootstrap_ssm" {
  type        = bool
  description = "After RDS is created, run an SSM document on the bastion to create app DB, roles, and schemas."
  default     = true
}

locals {
  name    = "dwp-platform-nonprod"
  region  = "eu-west-1"
  region2 = "eu-central-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name    = local.name
    Example = local.name
    Project = "DevOps with Prashant Platform"
  }
}