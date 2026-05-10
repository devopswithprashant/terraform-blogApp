terraform {
  backend "s3" {
    # Define the name of your bucket and the key for the state file.
    bucket               = "terraform-us-east-1-state-file"
    key                  = "dwp/eks-env/apps/terraform.tfstate"
    region               = "us-east-1"
    encrypt              = true
    workspace_key_prefix = ""
  }
}