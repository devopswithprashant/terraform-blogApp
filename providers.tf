terraform {
  required_version = ">= 1.11.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  #region = lookup(local.workspace_region_map, terraform.workspace, local.workspace_region_map.default)
  region = local.region
}

