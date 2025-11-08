# SSM Document for Initial Deployment (Infrastructure + App)
resource "aws_ssm_document" "k8s_initial_deploy" {
  name          = "K8SInitialDeploy"
  document_type = "Command"
  document_format = "YAML"

  content = <<-DOC
    schemaVersion: "2.2"
    description: "Initial deployment - Infrastructure and Application"
    parameters:
      environment:
        type: "String"
        description: "Environment name"
        default: "dev"
      gitRepo:
        type: "String"
        default: "https://github.com/your-org/k8s-infra.git"
      gitRef:
        type: "String"
        default: "main"
      appVersion:
        type: "String"
        default: "v1.0.0"

    mainSteps:
    - name: "DeployClusterComponents"
      action: "aws:runShellScript"
      inputs:
        runCommand:
          - |
            echo "Deploying cluster-level components..."
            REPO_DIR="/tmp/k8s-infra"
            git clone -b "{{ gitRef }}" "{{ gitRepo }}" "$REPO_DIR"
            cd "$REPO_DIR/cluster-setup"
            
            # Apply cluster components
            kubectl apply -f namespaces/
            #kubectl apply -f rbac/
            #kubectl apply -f storage/
            #kubectl apply -f monitoring/
            kubectl apply -f networking/

    - name: "DeployApplication"
      action: "aws:runShellScript"
      inputs:
        runCommand:
          - |
            echo "Deploying application components..."
            cd "/tmp/k8s-infra/applications"
            
            # Apply application in specific order
            kubectl apply -f 01-blogbackend/
            kubectl apply -f 02-blogfrontend/
            
            # kubectl apply -f 01-configurations/
            # kubectl apply -f 02-secrets/
            # kubectl apply -f 03-databases/
            # kubectl apply -f 04-backend/
            # kubectl apply -f 05-frontend/
            # kubectl apply -f 06-ingress/

    - name: "VerifyInitialDeployment"
      action: "aws:runShellScript"
      inputs:
        runCommand:
          - |
            echo "Verifying initial deployment..."
            # Wait for critical services
            kubectl wait --for=condition=ready pod -l app=blog-backend --timeout=300s
            kubectl wait --for=condition=ready pod -l app=blog-frontend --timeout=300s
            
            # Check all deployments
            kubectl get deployments --all-namespaces
            kubectl get services --all-namespaces
  DOC
}