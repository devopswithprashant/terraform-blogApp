# data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

# data "aws_vpc" "nonprod_blog" {
#   tags = {
#     Name = "nonprod-blog-vpc"
#     Type = "nonprod"
#   }
# }

# data "aws_subnets" "nonprod_blog_subnets" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.nonprod_blog.id]
#   }

#   tags = {
#     Type = "Private"
#   }
# }

# data "aws_subnets" "nonprod_blog_subnets_public" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.nonprod_blog.id]
#   }

#   tags = {
#     Type = "Public"
#   }
# }


data "aws_key_pair" "jumpserver_key" {
  key_name = "bastion-host-key"
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
