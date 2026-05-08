
################################################################################
# RDS Module
################################################################################


module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "7.2.0"

  identifier = local.workspaces[terraform.workspace].name

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine                   = "postgres"
  engine_version           = "17"
  engine_lifecycle_support = "open-source-rds-extended-support-disabled"
  family                   = "postgres17" # DB parameter group
  major_engine_version     = "17"         # DB option group
  instance_class           = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "blogdb"
  username = "blogdbadmin"
  port     = 5432

  # Setting manage_master_user_password_rotation to false after it
  # has previously been set to true disables automatic rotation
  # however using an initial value of false (default) does not disable
  # automatic rotation and rotation will be handled by RDS.
  # manage_master_user_password_rotation allows users to configure
  # a non-default schedule and is not meant to disable rotation
  # when initially creating / enabling the password management feature
  manage_master_user_password_rotation              = true
  master_user_password_rotate_immediately           = false
  master_user_password_rotation_schedule_expression = "rate(15 days)"

  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 1

  tags = local.workspaces[terraform.workspace].tags
}

# module "db_default" {
#   source  = "terraform-aws-modules/rds/aws"
#   version = "7.2.0"

#   identifier                     = "${local.name}-default"
#   instance_use_identifier_prefix = true

#   create_db_option_group    = false
#   create_db_parameter_group = false

#   # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
#   engine               = "postgres"
#   engine_version       = "17"
#   family               = "postgres17" # DB parameter group
#   major_engine_version = "17"         # DB option group
#   instance_class       = "db.t4g.large"

#   allocated_storage = 20

#   # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
#   # "Error creating DB Instance: InvalidParameterValue: MasterUsername
#   # user cannot be used as it is a reserved word used by the engine"
#   db_name  = "completePostgresql"
#   username = "complete_postgresql"
#   port     = 5432

#   db_subnet_group_name   = module.vpc.database_subnet_group
#   vpc_security_group_ids = [module.security_group.security_group_id]

#   maintenance_window      = "Mon:00:00-Mon:03:00"
#   backup_window           = "03:00-06:00"
#   backup_retention_period = 0

#   tags = local.tags
# }


module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.workspaces[terraform.workspace].name
  description = "Complete PostgreSQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.workspaces[terraform.workspace].tags
}


################################################################################
# RDS Automated Backups Replication Module
################################################################################

# provider "aws" {
#   alias  = "region2"
#   region = local.workspaces[terraform.workspace].region2
# }

# module "kms" {
#   source      = "terraform-aws-modules/kms/aws"
#   version     = "~> 1.0"
#   description = "KMS key for cross region automated backups replication"

#   # Aliases
#   aliases                 = [local.name]
#   aliases_use_name_prefix = true

#   key_owners = [data.aws_caller_identity.current.arn]

#   tags = local.tags

#   providers = {
#     aws = aws.region2
#   }
# }

# # module "db_automated_backups_replication" {
# #   source = "../../modules/db_instance_automated_backups_replication"

# #   source_db_instance_arn = module.db.db_instance_arn
# #   kms_key_arn            = module.kms.key_arn

# #   providers = {
# #     aws = aws.region2
# #   }
# # }

# resource "aws_db_instance_automated_backups_replication" "this" {
#   provider = aws.region2
#   source_db_instance_arn = module.db.db_instance_arn
#   kms_key_id             = module.kms.key_arn
#   pre_signed_url         = null
#   region                 = local.region2
#   retention_period       = 7
# }
