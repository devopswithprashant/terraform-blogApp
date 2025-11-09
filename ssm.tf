# SSM Document for Kubernetes Deployment with Proper Tag/Branch Handling
resource "aws_ssm_document" "k8s_deployer" {
  name          = "K8SDeployer"
  document_type = "Command"
  document_format = "YAML"

  content = file("${path.module}/SSM_k8s_deployer.yaml")

  tags = {
    Name = "k8s-deployer"
  }
}