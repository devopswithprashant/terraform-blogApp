# terraform-blogApp

This is an **Infrastructure as Code (IaC)** repository for the DevOps with Prashant blog application's AWS infrastructure. It provisions a complete Amazon EKS (Elastic Kubernetes Service) cluster along with all supporting resources required for running a containerized blog application on Kubernetes.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Configuration Details](#configuration-details)
- [Deployment](#deployment)
- [Security Considerations](#security-considerations)
- [Outputs](#outputs)
- [Cleanup](#cleanup)

## Overview

This Terraform project automates the provisioning of:

- **AWS EKS Cluster** - Kubernetes control plane with private API endpoint
- **EKS Node Group** - Managed worker nodes for running containerized workloads
- **Bastion Host** - Jump server for secure cluster management
- **IAM Roles & Policies** - Fine-grained access control for cluster components
- **Security Groups** - Network-level access controls
- **AWS Systems Manager Integration** - Automated Kubernetes deployment automation

**Target Environment:** Non-production blog application infrastructure in AWS us-east-1 region

## Architecture

### Core Components

#### 1. EKS Cluster (`cluster.tf`)
- **Kubernetes Version:** 1.33
- **Authentication Mode:** API (IAM-based)
- **API Endpoint:** Private access only (not publicly accessible)
- **Networking:** Spans 3 private subnets across availability zones
- **IAM Role:** `blogapp-cluster-eks-role` with EKS cluster policy

**Key Features:**
- Private endpoint ensures cluster API is only accessible from within the VPC or through bastion
- Zonal shift disabled for predictable behavior in non-production environment
- Security group controls ingress/egress traffic to cluster

#### 2. Node Group (`nodegroup.tf`)
- **Name:** `private-large`
- **Instance Type:** `m6g.large` (ARM-based Graviton processor)
- **AMI Type:** AL2023_ARM_64_STANDARD (Amazon Linux 2 with ARM support)
- **Capacity Type:** On-demand instances
- **Scaling Configuration:**
  - Desired: 1 node
  - Min: 1 node
  - Max: 2 nodes
- **IAM Role:** `blogapp-cluster-eks-node-group-role`

**Attached IAM Policies:**
- `AmazonEKSWorkerNodePolicy` - Core worker node permissions
- `AmazonEKS_CNI_Policy` - Container Network Interface management
- `AmazonEC2ContainerRegistryReadOnly` - ECR read access for pulling container images

#### 3. Bastion Host (`bastion.tf`)
- **Instance Type:** `t2.micro` (cost-effective for non-production)
- **AMI:** Ubuntu-based EC2 instance (`ami-0ecb62995f68bb549`)
- **Placement:** Public subnet for SSH access
- **Public IP:** Enabled for remote access
- **Key Pair:** `testing`
- **Initialization:** Runs `bastion-setup.sh` script on first boot
- **IAM Profile:** Linked to `eks-jumpserver-role` with EKS cluster admin access

**Security Group Rules:**
- **Ingress:** SSH (port 22) from 0.0.0.0/0 ⚠️ (restrict to your IP in production)
- **Egress:** All protocols to 0.0.0.0/0

#### 4. Networking (`data.tf`)
References existing infrastructure in the VPC `nonprod-blog-vpc`:
- **Private Subnets:** Tagged with `Type: Private` (3 subnets for EKS cluster)
- **Public Subnets:** Tagged with `Type: Public` (for bastion host)
- **Key Pair:** Uses existing `testing` key pair for bastion SSH access

#### 5. Systems Manager (`ssm.tf`)
- **Document Name:** `K8SDeployer`
- **Type:** Command document in YAML format
- **Purpose:** Automated Kubernetes deployment orchestration
- **Configuration:** Defined in `SSM-k8s-deployer.yaml`

## Prerequisites

### Required AWS Resources (Pre-existing)
Before running this Terraform, ensure the following resources exist in your AWS account:

1. **VPC** - Tagged with `Name: nonprod-blog-vpc` and `Type: nonprod`
2. **Subnets** - At least 3 private subnets and 1 public subnet, properly tagged:
   - Private subnets: `Type: Private`
   - Public subnets: `Type: Public`
3. **EC2 Key Pair** - Named `testing` for bastion SSH access
4. **S3 Bucket** - `terraform-us-east-1-state-file` for Terraform state storage

### Tools & Credentials
- **Terraform** >= 1.0
- **AWS CLI** v2 with configured credentials
- **Kubectl** (optional, for Kubernetes management)
- AWS IAM permissions to create EKS clusters, EC2 instances, IAM roles, and security groups

## Project Structure

```
terraform-blogApp/
├── README.md                      # Project documentation
├── providers.tf                   # AWS provider configuration
├── variables.tf                   # Local variables definition
├── cluster.tf                     # EKS cluster & cluster IAM resources
├── nodegroup.tf                   # EKS node group & node IAM resources
├── bastion.tf                     # Bastion host & related resources
├── data.tf                        # Data sources (VPC, subnets, key pair)
├── ssm.tf                         # AWS Systems Manager document
├── backend.tf                     # S3 remote state configuration
├── output.tf                      # Output values (currently commented out)
├── bastion-setup.sh               # Initialization script for bastion host
├── SSM-k8s-deployer.yaml          # K8s deployment automation document
├── LICENSE                        # Repository license
└── .github/
    └── workflows/
        └── destroy.yml            # GitHub Actions workflow for infrastructure destruction
```

## Configuration Details

### AWS Region & Provider
- **Region:** `us-east-1`
- **AWS Provider Version:** ~> 6.0
- **Terraform State:** Remote S3 backend (encrypted)

### Locals
```hcl
locals {
  name = "blogapp-cluster"
}
```
Used as a common name prefix for all resources (EKS cluster, IAM roles, etc.)

### Tagging Strategy
Resources are tagged with descriptive names:
- EKS Cluster: `blogapp-cluster`
- Bastion Host: `eks-bastion-blogapp`
- Security Groups: `jumpserver-sg`, `eks-additional-sg`
- IAM Roles: `blogapp-cluster-eks-role`, `blogapp-cluster-eks-node-group-role`, `eks-jumpserver-role`

## Deployment

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd terraform-blogApp
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```
   This downloads the AWS provider and configures the S3 backend.

3. **Validate configuration:**
   ```bash
   terraform validate
   ```

4. **Plan the deployment:**
   ```bash
   terraform plan -out=tfplan
   ```
   Review the resources that will be created.

5. **Apply the configuration:**
   ```bash
   terraform apply tfplan
   ```

### GitHub Actions Automated Deployment

This project includes CI/CD pipelines using GitHub Actions for automated infrastructure management. Two workflows are available: **Deploy** and **Destroy**.

#### Prerequisites for GitHub Actions

Before running the workflows, configure the following:

1. **AWS OIDC Provider** (Recommended for secure, credential-less authentication)
   - Create an OIDC provider in AWS IAM connected to your GitHub organization
   - This allows GitHub Actions to assume AWS roles without storing long-lived credentials

2. **GitHub Repository Secrets**
   - Add the following secret to your repository:
     - `AWS_ADMIN_ROLE`: ARN of the IAM role for Terraform operations
       Example: `arn:aws:iam::123456789012:role/GitHubActionsTerraformRole`

3. **GitHub Repository Environment**
   - Create a `dev` environment in your repository settings (Settings → Environments)
   - This ensures workflows run in a controlled environment

#### Deploy Workflow (`.github/workflows/deploy.yml`)

**Purpose:** Automatically validates, plans, and applies Terraform changes

**Trigger Events:**
- ✅ Manual trigger: `workflow_dispatch` button in GitHub Actions tab
- ✅ Push to `main` branch (auto-apply only on push to main)
- ✅ Pull requests (plan only, no apply)

**Workflow Steps:**

1. **Checkout Code**
   - Clones the repository to the Ubuntu runner

2. **Setup Terraform**
   - Installs Terraform v1.13.5
   - Configures Terraform CLI environment

3. **Configure AWS Credentials**
   - Authenticates with AWS using OIDC
   - Assumes the role specified in `AWS_ADMIN_ROLE` secret
   - Session name: `GitHubActionsTerraform`
   - Region: `us-east-1`

4. **Terraform Init**
   ```bash
   terraform init
   ```
   - Initializes Terraform working directory
   - Downloads AWS provider plugins
   - Configures S3 remote backend

5. **Terraform Validate**
   ```bash
   terraform validate
   ```
   - Validates Terraform configuration syntax
   - Checks for configuration errors

6. **Terraform Format Check**
   ```bash
   terraform fmt -check
   ```
   - Ensures all files follow HCL formatting standards
   - Fails if any files are not properly formatted

7. **Terraform Plan**
   ```bash
   terraform plan -input=false -out=tfplan.out
   ```
   - Generates execution plan
   - Outputs plan to `tfplan.out` for review
   - Shows what resources will be created/modified/destroyed

8. **Terraform Apply** (Conditional)
   ```bash
   terraform apply tfplan.out
   ```
   - **Only runs on:** `push` to `main` branch
   - **Skipped on:** Pull requests and manual dispatch (for safety)
   - Applies the infrastructure changes

**Usage:**

```bash
# Option 1: Manual trigger (plan only)
# Go to GitHub → Actions → Deploy → Run workflow

# Option 2: Create a Pull Request
# - Workflow automatically runs on PR creation
# - Shows terraform plan in PR comments for review
# - Approval/merge required before applying

# Option 3: Push to main branch
# - Workflow automatically plans and applies changes
# - Use with caution in production environments
```

#### Destroy Workflow (`.github/workflows/destroy.yml`)

**Purpose:** Safely tears down all infrastructure managed by Terraform

**Trigger Events:**
- ✅ Manual trigger only: `workflow_dispatch` button in GitHub Actions tab
- ❌ No automatic triggers (safe by design)

**Workflow Steps:**

1. **Checkout Code**
   - Clones the repository to the Ubuntu runner

2. **Setup Terraform**
   - Installs Terraform v1.13.5

3. **Configure AWS Credentials**
   - Authenticates with AWS using OIDC
   - Assumes the role specified in `AWS_ADMIN_ROLE` secret
   - Region: `us-east-1`

4. **Terraform Init**
   ```bash
   terraform init
   ```
   - Initializes Terraform working directory

5. **Terraform Format Check**
   ```bash
   terraform fmt -check
   ```
   - Validates code formatting

6. **Terraform Plan Destroy**
   ```bash
   terraform plan -destroy -input=false -out=tfplan.out
   ```
   - Shows what will be destroyed
   - Outputs plan to `tfplan.out` for review

7. **Terraform Destroy** (Conditional)
   ```bash
   terraform apply tfplan.out
   ```
   - **Only runs on:** `main` branch
   - **Safety feature:** Requires manual approval via workflow dispatch
   - Permanently deletes all infrastructure

**Usage:**

```bash
# Manual destruction via GitHub Actions
# Go to GitHub → Actions → Destroy → Run workflow

# This will:
# 1. Generate a destruction plan
# 2. Ask for confirmation (workflow logs)
# 3. Destroy all infrastructure

# WARNING: This is irreversible. Ensure you have:
# - Backups of any important data
# - Removed Kubernetes resources (PVCs, LBs, etc.)
# - Notified team members
```

#### Workflow Security Features

| Feature | Deploy Workflow | Destroy Workflow |
|---------|-----------------|------------------|
| OIDC Authentication | ✅ Yes | ✅ Yes |
| Environment Protection | ✅ Yes (dev) | ✅ Yes (dev) |
| Concurrency Control | ✅ Enabled | ✅ Enabled |
| Manual Approval | ❌ (auto on main) | ✅ Required |
| PR Support | ✅ (plan only) | ❌ No |
| Log/Audit Trail | ✅ Full | ✅ Full |

**Concurrency Control:**
- Only one workflow per branch can run simultaneously
- New runs cancel in-progress runs on same branch
- Prevents terraform state conflicts

#### Troubleshooting GitHub Actions

**Issue: Workflow fails with "InvalidClientTokenId" or permission denied**
- Verify `AWS_ADMIN_ROLE` secret is set correctly
- Check IAM role trust relationship includes GitHub OIDC provider
- Confirm role has permissions: `sts:AssumeRole`, `sts:TagSession`

**Issue: "terraform fmt -check" fails**
- Run locally: `terraform fmt -recursive` to auto-format
- Commit and push the formatted files

**Issue: Workflow hangs on "Terraform Init"**
- Check S3 bucket `terraform-us-east-1-state-file` exists
- Verify IAM role has S3 permissions for state bucket
- Check DynamoDB lock table (if configured)

**Issue: "Apply" step skipped on push to main**
- Verify the commit was pushed directly to `main` (not via PR merge)
- Check workflow logs for event type (should be `push`, not `pull_request`)

#### Best Practices

1. **Always review terraform plan before merge**
   - Comment on PR to discuss changes
   - Use `terraform show tfplan.out` to inspect detailed changes

2. **Protect main branch**
   - Require PR reviews before merge
   - Enable status checks for workflow success
   - Restrict who can merge to main

3. **Monitor workflow execution**
   - Enable GitHub Actions notifications
   - Review logs after each run
   - Track infrastructure changes in commit history

4. **State file management**
   - Regularly backup S3 state bucket: `aws s3 cp s3://terraform-us-east-1-state-file/ ./backup/ --recursive`
   - Enable S3 versioning for state recovery
   - Restrict state bucket access to CI/CD role only

5. **Local development**
   - Always run `terraform validate` locally before pushing
   - Use `terraform plan` to preview changes
   - Test in non-production environments first

### Accessing the Cluster

After deployment (via GitHub Actions or manually), connect to the bastion host and configure kubectl:

```bash
# SSH into bastion
ssh -i ~/.ssh/testing.pem ec2-user@<bastion-public-ip>

# Configure kubeconfig (from bastion)
aws eks update-kubeconfig --region us-east-1 --name blogapp-cluster

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

## Security Considerations

### Current Security Posture ⚠️

**Production-Ready Issues to Address:**

1. **SSH Access (Bastion)** - Currently open to 0.0.0.0/0
   - **Recommendation:** Restrict `cidr_blocks` in `bastion.tf` to your specific IP address
   - Example: `cidr_blocks = ["203.0.113.0/32"]`

2. **Private EKS Endpoint** ✅
   - Already configured for security
   - Only accessible from within VPC or through bastion

3. **IAM-based Authentication** ✅
   - EKS uses AWS IAM for authentication
   - No basic auth enabled

4. **Encrypted State File** ✅
   - Terraform state is encrypted in S3
   - Ensure S3 bucket versioning and access logging are enabled

### Hardening Recommendations

- Enable VPC Flow Logs for network monitoring
- Implement network policies in Kubernetes (Calico/Cilium)
- Use AWS Secrets Manager for sensitive configuration
- Enable EKS control plane logging
- Implement Pod Security Standards/Policies
- Use IAM roles for Kubernetes service accounts (IRSA)

## Outputs

Currently, output values are commented out in `output.tf`. Consider enabling:

- EKS cluster endpoint
- EKS cluster security group ID
- Bastion instance public IP
- Node group ID
- IAM role ARNs

Example output configuration:
```hcl
output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.my_eks_cluster.endpoint
  description = "EKS cluster API endpoint"
}

output "bastion_public_ip" {
  value       = aws_instance.eks_jumpserver.public_ip
  description = "Bastion host public IP address"
}
```

## Cleanup

### Destroy Infrastructure
Use the GitHub Actions workflow or manually:

```bash
terraform destroy
```

**Note:** Ensure no Kubernetes resources (LoadBalancers, PVCs) are pending in the cluster before destroying, as they may create AWS resources outside of Terraform's scope.

### S3 State File Management
```bash
# Backup state before destruction
aws s3 cp s3://terraform-us-east-1-state-file/eks/basic/blogapp/terraform.tfstate ./terraform.tfstate.backup

# After successful destruction, optionally remove state file
aws s3 rm s3://terraform-us-east-1-state-file/eks/basic/blogapp/terraform.tfstate
```

## CI/CD Integration

### GitHub Actions Workflow

**Destroy Workflow** (`.github/workflows/destroy.yml`):
- **Trigger:** Manual (`workflow_dispatch`)
- **Authentication:** OIDC with AWS
- **Environment:** `dev`
- **Purpose:** Safely destroy infrastructure through automated workflow

### Setting Up OIDC Authentication

To use GitHub Actions with AWS without storing credentials:

1. Create OIDC provider in AWS
2. Configure GitHub Actions secrets for AWS account/role details
3. Workflows will authenticate using temporary credentials

## Troubleshooting

### Common Issues

1. **Terraform plan fails with "VPC not found"**
   - Verify the VPC `nonprod-blog-vpc` exists in us-east-1
   - Check that subnets are properly tagged

2. **Bastion SSH connection refused**
   - Verify security group allows inbound SSH
   - Check key pair name matches `testing`
   - Wait 2-3 minutes for user_data script to complete

3. **EKS cluster creation times out**
   - Check AWS service limits and quotas
   - Verify IAM role has necessary permissions
   - Review CloudFormation events in AWS Console

4. **Node group fails to scale**
   - Verify subnet capacity
   - Check IAM role policies are attached
   - Review EC2 instance limits in the region

## Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)

## License

See [LICENSE](LICENSE) file for details.

---

**Last Updated:** January 2026
**Maintained By:** DevOps with Prashant
