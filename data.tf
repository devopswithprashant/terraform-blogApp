# data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}


data "aws_key_pair" "jumpserver_key" {
  key_name = local.workspaces[terraform.workspace].bastion_host_key_name
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
