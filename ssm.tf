# SSM Document for Kubernetes Deployment with Proper Tag/Branch Handling
resource "aws_ssm_document" "k8s_deployer" {
  name          = "K8SDeployer"
  document_type = "Command"
  document_format = "YAML"

  content = <<-DOC
    schemaVersion: "2.2"
    description: "Deploy Kubernetes manifests from Git repository"
    parameters:
      gitRepository:
        type: "String"
        description: "Git repository URL containing Kubernetes manifests"
        default: "https://github.com/devopswithprashant/k8-blogApp.git"
      gitRef:
        type: "String"
        description: "Git reference (branch name or tag name)"
        default: "main"
      gitRefType:
        type: "String"
        description: "Type of git reference - 'branch' for development, 'tag' for releases"
        default: "branch"
        allowedValues:
          - "branch"
          - "tag"
      gitToken:
        type: "String"
        description: "Git token for private repositories (leave empty for public repos)"
        default: ""
        noEcho: true
      manifestDirectory:
        type: "String"
        description: "Directory containing manifest files in the repository"
        default: "/"
      fileSequence:
        type: "String"
        description: "Comma-separated list of manifest files in deployment order"
        default: "00-namespace.yaml,01-configmap.yaml,02-secret.yaml,03-deployment.yaml,04-service.yaml,05-ingress.yaml"
      kubeconfigPath:
        type: "String"
        description: "Path to kubeconfig file"
        default: "/home/ubuntu/.kube/config"
      awsRegion:
        type: "String"
        description: "AWS region"
        default = "us-east-1"
      clusterName:
        type: "String"
        description: "Name of the EKS cluster"
        default = ""

    mainSteps:
    - name: "ValidateParameters"
      action: "aws:runShellScript"
      inputs:
        runCommand:
          - |
            echo "Starting Kubernetes deployment from Git..."
            echo "Repository: {{ gitRepository }}"
            echo "Git Reference: {{ gitRef }} ({{ gitRefType }})"
            echo "Deployment Type: $(if [ '{{ gitRefType }}' = 'tag' ]; then echo 'RELEASE DEPLOYMENT'; else echo 'DEVELOPMENT DEPLOYMENT'; fi)"
            echo "Git Token: $(if [ -n '{{ gitToken }}' ]; then echo '***PROVIDED***'; else echo 'Not provided (public repo)'; fi)"
            echo "Manifest Directory: {{ manifestDirectory }}"
            echo "File Sequence: {{ fileSequence }}"

            # Validate git reference type
            if [ "{{ gitRefType }}" != "branch" ] && [ "{{ gitRefType }}" != "tag" ]; then
              echo "ERROR: gitRefType must be either 'branch' or 'tag'"
              exit 1
            fi

    - name: "CloneGitRepository"
      action: "aws:runShellScript"
      inputs:
        runCommand:
          - |
            set -e
            echo "Cloning Git repository..."
            
            # Create unique directory for this deployment
            REPO_DIR="/tmp/k8s-manifests-$(date +%s)"
            
            # Prepare repository URL with authentication if token is provided
            CLONE_URL="{{ gitRepository }}"
            if [ -n "{{ gitToken }}" ]; then
              echo "Using authentication token for private repository..."
              if [[ "{{ gitRepository }}" =~ ^https://([^/]+)/(.+)$ ]]; then
                DOMAIN="$${BASH_REMATCH[1]}"
                REPO_PATH="$${BASH_REMATCH[2]}"
                CLONE_URL="https://{{ gitToken }}@$DOMAIN/$REPO_PATH"
              fi
            fi

            # Clone based on reference type
            if [ "{{ gitRefType }}" = "tag" ]; then
              echo "🔖 CLONING SPECIFIC RELEASE TAG: {{ gitRef }}"
              echo "This is a RELEASE deployment - using immutable tag"
              
              # Clone the repository (shallow clone of the default branch first)
              git clone --depth 1 "$CLONE_URL" "$REPO_DIR"
              cd "$REPO_DIR"
              
              # Fetch and checkout the specific tag
              git fetch --tags
              if git checkout "tags/{{ gitRef }}" -b "temp-tag-{{ gitRef }}"; then
                echo "✅ Successfully checked out tag: {{ gitRef }}"
                echo "Tag commit: $(git rev-parse HEAD)"
              else
                echo "❌ ERROR: Tag '{{ gitRef }}' not found in repository"
                echo "Available tags:"
                git tag -l | head -10
                exit 1
              fi
            else
              echo "🌿 CLONING BRANCH: {{ gitRef }}"
              echo "This is a DEVELOPMENT deployment - using branch"
              
              # Clone the specific branch (development)
              git clone --depth 1 --branch "{{ gitRef }}" "$CLONE_URL" "$REPO_DIR"
              cd "$REPO_DIR"
              echo "Branch {{ gitRef }} is at commit: $(git rev-parse HEAD)"
            fi

            # Navigate to manifest directory
            cd "{{ manifestDirectory }}"
            echo "Repository cloned to: $REPO_DIR"
            echo "Current directory: $(pwd)"
            echo "Files in manifest directory:"
            ls -la

    - name: "UpdateKubeconfig"
      action: "aws:runShellScript"
      inputs:
        runCommand:
          - |
            echo "Updating kubeconfig..."
            # Ensure kubeconfig directory exists
            mkdir -p $(dirname "{{ kubeconfigPath }}")
            
            # Update kubeconfig for EKS cluster
            aws eks update-kubeconfig --region "{{ awsRegion }}" --name "{{ clusterName }}" --kubeconfig "{{ kubeconfigPath }}"
            
            # Verify cluster access
            kubectl --kubeconfig "{{ kubeconfigPath }}" cluster-info
            kubectl --kubeconfig "{{ kubeconfigPath }}" get nodes


    - name: "DeployApplication"
      action: "aws:runShellScript"
      inputs:
        runCommand:
          - |
            echo "Deploying application components..."
            cd "/tmp/k8s-infra/applications"
            
            # Apply application in specific order
            kubectl apply -f backend/
            kubectl apply -f frontend/
            
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

    - name: "Cleanup"
      action: "aws:runShellScript"
      inputs:
        runCommand:
          - |
            echo "Cleaning up temporary files..."
            rm -rf /tmp/k8s-manifests-*
            echo "✅ Deployment completed successfully!"
            echo "📋 Deployment Summary:"
            echo "   - Git Reference: {{ gitRef }} ({{ gitRefType }})"
            echo "   - Repository: {{ gitRepository }}"
            echo "   - Timestamp: $(date)"
  DOC

  tags = {
    Name = "k8s-deployer"
  }
}