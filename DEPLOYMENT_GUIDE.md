# ElderPing Infrastructure - Terraform Deployment Guide

## Overview

This repository contains Infrastructure-as-Code (IaC) for the **ElderPing** application deployed on AWS using Terraform. The infrastructure is production-ready with high availability, security, monitoring, and automatic scaling capabilities.

---

## 📋 What Has Been Deployed

### Core Infrastructure
- **VPC**: Custom VPC with 6 subnets across 2 availability zones (AZs)
  - 2 Public subnets for load balancing
  - 2 Private application subnets for EC2 instances
  - 2 Private database subnets for RDS

- **Security**: Multi-layer security implementation
  - Security groups with fine-grained access controls
  - KMS encryption for all data at rest
  - VPC Endpoints for secure AWS service access without NAT Gateway costs

- **Database**: PostgreSQL 15 RDS Instance
  - Multi-AZ deployment for high availability
  - Automatic backups (7 days retention)
  - Enhanced monitoring via CloudWatch
  - Parameter group with query logging (DDL statements)

### Application Layer
- **Auto Scaling Group**: EC2 instances running containerized application
  - Min: 1, Desired: 2, Max: 4 instances
  - Instance type: t3.medium (configurable)
  - Image: Amazon Linux 2023 AMI
  - Automatic scaling based on metrics
  - EC2 instances pull Docker images from ECR

- **Load Balancing**: 
  - Application Load Balancer (ALB) with HTTPS termination
  - Target group with health checks
  - Deletion protection enabled

- **CDN**: CloudFront distribution
  - Caches static assets (/static/*)
  - HTTPS only protocol
  - Custom origin verification header
  - WAF protection enabled

- **DNS**: Route53
  - Custom domain with HTTPS certificate (ACM)
  - Auto-renewal of SSL certificates

### Backend Services
- **Lambda Function**: Automated reminder handler
  - Triggered every 10 minutes via EventBridge
  - Fetches upcoming medication reminders from RDS
  - Publishes notifications via SNS
  - Connects to RDS securely through VPC endpoints

- **SNS Topics**: Three separate topics for different alert types
  - Medication reminders
  - Caregiver alerts
  - Infrastructure alarms

- **S3 Buckets**: 
  - ALB access logs
  - Application backups
  - CloudTrail audit logs

### Observability & Security
- **CloudWatch**: 
  - Log groups for ALB, Lambda, RDS, and application
  - Custom alarms for:
    - High CPU/memory usage on EC2
    - RDS connection issues
    - ALB target health
    - Unusual request patterns

- **CloudTrail**: Audit logging for compliance
  - All API calls logged to S3
  - KMS encryption

- **Secrets Manager**: 
  - RDS credentials
  - JWT secrets
  - SMTP credentials (optional)
  - Automatic rotation support

---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                  │
└────────────────┬────────────────────────────────────────────────┘
                 │ HTTPS
                 ▼
        ┌─────────────────┐
        │   CloudFront    │ ◄─── WAF (DDoS/SQL Injection Protection)
        │     (CDN)       │
        └────────┬────────┘
                 │
                 ▼
        ┌─────────────────┐
        │ Route53 + ACM   │ ◄─── Domain + SSL Certificate
        │   (DNS/TLS)     │
        └────────┬────────┘
                 │
                 ▼
    ┌────────────────────────────┐
    │          ALB               │
    │   (HTTPS Termination)      │
    │  Deletion Protected        │
    └────────┬────────┬──────────┘
             │        │
             ▼        ▼
    ┌──────────────────────────────────────────────────────────┐
    │                    VPC 10.0.0.0/16                       │
    │                                                           │
    │  ┌────────────────────────────────────────────────────┐  │
    │  │        Public Subnets (ALB)                        │  │
    │  │  10.0.1.0/24 (AZ-a)  │  10.0.2.0/24 (AZ-b)        │  │
    │  └────────────────────────────────────────────────────┘  │
    │                                                           │
    │  ┌────────────────────────────────────────────────────┐  │
    │  │    Private App Subnets (EC2 instances)             │  │
    │  │  10.0.11.0/24 (AZ-a) │ 10.0.12.0/24 (AZ-b)        │  │
    │  │  ┌──────────┐ ┌───────────┐ ┌──────────┐          │  │
    │  │  │   EC2    │ │  EC2      │ │  Lambda  │          │  │
    │  │  │ (t3.med) │ │(t3.med)   │ │(Reminder)│          │  │
    │  │  └──────────┘ └───────────┘ └──────────┘          │  │
    │  │       ASG: Min 1, Desired 2, Max 4                │  │
    │  └────────────────────────────────────────────────────┘  │
    │                                                           │
    │  ┌────────────────────────────────────────────────────┐  │
    │  │    Private DB Subnets (RDS Cluster)                │  │
    │  │  10.0.21.0/24 (AZ-a) │ 10.0.22.0/24 (AZ-b)        │  │
    │  │          ┌─────────────────┐                       │  │
    │  │          │ PostgreSQL RDS  │◄─ Multi-AZ           │  │
    │  │          │  (db.t3.medium) │   Automatic Backup   │  │
    │  │          │  100 GB Storage │   (7 days)            │  │
    │  │          └─────────────────┘                       │  │
    │  └────────────────────────────────────────────────────┘  │
    │                                                           │
    │  ┌────────────────────────────────────────────────────┐  │
    │  │         VPC Endpoints (No NAT Gateway costs)       │  │
    │  │  • S3           • Secrets Manager                  │  │
    │  │  • DynamoDB     • EC2 Messages                     │  │
    │  │  • SSM                                            │  │
    │  └────────────────────────────────────────────────────┘  │
    │                                                           │
    └────────────────────────────────────────────────────────┘
             │
             ├─────────────────┬──────────────────┐
             ▼                 ▼                  ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │   S3         │  │ CloudWatch   │  │  Secrets     │
    │ • Backups    │  │ • Logs       │  │  Manager     │
    │ • ALB Logs   │  │ • Alarms     │  │ • DB Creds   │
    │ • CloudTrail │  │ • Metrics    │  │ • JWT Secret │
    │   Logs       │  │              │  │ • SMTP Auth  │
    └──────────────┘  └──────────────┘  └──────────────┘
             │
             ▼
    ┌──────────────────────────────────────┐
    │  SNS Topics (Email Notifications)    │
    │  • Medication Reminders              │
    │  • Caregiver Alerts                  │
    │  • Infrastructure Alarms             │
    └──────────────────────────────────────┘
```

---

## 🔐 Security Features Implemented

✅ **Encryption**
- KMS encryption at rest for all S3, RDS, DynamoDB, and CloudWatch Logs
- TLS 1.2+ for all data in transit
- HTTPS enforced via CloudFront and ALB

✅ **Network Security**
- VPC with private subnets for database and application
- Security groups with least-privilege access
- VPC Endpoints eliminate need for NAT Gateway
- No instances have direct internet access

✅ **Access Control**
- IAM roles with fine-grained permissions
- SSM Session Manager for EC2 access (no SSH keys)
- Secrets Manager for credential rotation

✅ **Compliance & Auditing**
- CloudTrail logs all API calls
- CloudWatch logs with 30-day retention
- Enhanced RDS monitoring

✅ **DDoS & Web Protection**
- AWS WAF integrated with CloudFront
- Rate limiting and rule-based protection

---

## 📋 Pre-Deployment Requirements

### AWS Account Setup (Manual Steps Required in AWS Console)

#### 1. **Terraform State Backend** ⚠️ MUST DO FIRST
```
Before running 'terraform init', create:
- S3 Bucket: elderping-terraform-state
  • Enable versioning
  • Enable server-side encryption with KMS
  • Block all public access
  
- DynamoDB Table: elderping-terraform-locks
  • Partition key: LockID (String)
  • Billing mode: Pay per request
```

**Why**: Terraform needs these to store state remotely and prevent concurrent modifications.

#### 2. **KMS Key** (Can be auto-created by Terraform)
The `kms` module will create a key, but you can pre-create one:
- Key name: `elderping-main`
- Enable key rotation: Yes
- Key policy: Allow Terraform role to use it

#### 3. **Route53 Hosted Zone** ⚠️ REQUIRED
```
Create a hosted zone for: elderping.online
- Copy the nameservers from Route53
- Update your domain registrar to use these nameservers
```

**Why**: Required for SSL certificate validation and DNS routing.

#### 4. **ECR Repository** (Optional but Recommended)
```
Create: 123456789012.dkr.ecr.us-east-1.amazonaws.com/elderping
- Image name: elderping
- Push your Docker image with tag "latest"
```

#### 5. **IAM User / Role for Terraform**
Create an IAM user with programmatic access and attach:
- Policy: AdministratorAccess (or more restrictive custom policy)
- Generate Access Key ID and Secret Access Key

#### 6. **Generate Secrets** (Before Terraform Apply)
```bash
# Database credentials (min 16 chars)
export TF_VAR_db_username="elderping_admin"
export TF_VAR_db_password="$(openssl rand -base64 32)"

# JWT secret for application
export TF_VAR_jwt_secret="$(openssl rand -hex 32)"

# SMTP (if using email - optional)
# export TF_VAR_smtp_host="smtp.gmail.com"
# export TF_VAR_smtp_port="587"
# export TF_VAR_smtp_username="your-email@gmail.com"
# export TF_VAR_smtp_password="your-app-password"
```

---

## 🚀 Step-by-Step Deployment Guide

### Prerequisites
- ✅ AWS CLI installed and configured
- ✅ Terraform >= 1.7.0 installed
- ✅ Pre-deployment requirements completed above
- ✅ SSH key pair created (aws ec2 create-key-pair --key-name elderping)

### Step 1: Configure AWS Credentials

```bash
# Option 1: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Option 2: AWS CLI configuration
aws configure
# Enter your credentials when prompted
```

### Step 2: Set Required Environment Variables

```bash
# Navigate to prod environment
cd environments/prod

# Set database credentials
export TF_VAR_db_username="elderping_admin"
export TF_VAR_db_password="<min-16-character-password>"

# Set JWT secret
export TF_VAR_jwt_secret="$(openssl rand -hex 32)"

# Set email notifications (optional)
# export TF_VAR_alarm_email_addresses='["ops@elderping.com"]'

# Optional: SMTP credentials for email sending
# export TF_VAR_smtp_host="smtp.gmail.com"
# export TF_VAR_smtp_port="587"
# export TF_VAR_smtp_username="your-email@gmail.com"
# export TF_VAR_smtp_password="your-app-password"
```

### Step 3: Initialize Terraform

```bash
terraform init

# Output should include:
# - Backend configured successfully
# - Provider plugins downloaded (aws, random, archive)
# - Terraform initialized successfully
```

### Step 4: Review Configuration

```bash
# Validate syntax
terraform validate

# Plan the deployment (shows what will be created)
terraform plan -out=tfplan

# Review output carefully:
# - Check all resource names are correct
# - Verify instance counts and sizes
# - Confirm database settings
# - Validate variable values

# Save plan to file
terraform show tfplan > deployment_plan.txt
```

---

## 🧪 Dev Environment and Workspaces

This repo currently uses a dedicated `prod` environment configuration in `environments/prod`.

### Option A: Separate dev/prod environment directories
The safest setup is to create `environments/dev` with the same Terraform files as `environments/prod`, but set the backend key to `dev/terraform.tfstate` and use dev-specific variables:
- `environment = "dev"`
- `project = "elderping-dev"`
- `ecr_registry` and `image_tag` for your dev images

That gives independent state and avoids workspace state migration issues.

### Option B: Use Terraform workspaces
If you want Terraform workspaces, change the backend key to:
```hcl
key = "${terraform.workspace}/terraform.tfstate"
```
Then create and select workspaces:
```bash
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
```
Use workspace-specific variable files:
- `terraform.dev.tfvars`
- `terraform.prod.tfvars`

> Note: the current backend is fixed to `prod/terraform.tfstate`, so workspaces require backend key adjustment and possibly manual state migration.

### Recommended dev workflow
```bash
cd environments/prod
terraform init
terraform workspace new dev
terraform workspace select dev
terraform plan -var-file=terraform.dev.tfvars
terraform apply -var-file=terraform.dev.tfvars
```

---

### Step 5: Deploy Infrastructure

```bash
# Apply the Terraform configuration
terraform apply tfplan

# This takes ~25-40 minutes (mainly RDS provisioning)
# DO NOT cancel the process
```

### Step 6: Retrieve Outputs

```bash
# After successful apply, get important values
terraform output

# Key outputs to note:
# - alb_dns_name: ALB endpoint (for verification)
# - cloudfront_domain_name: CDN endpoint
# - rds_address: Database endpoint
# - app_url: Application URL
# - asg_name: Auto Scaling Group name
```

### Step 7: Post-Deployment Configuration

#### A. Verify Infrastructure

```bash
# Check ALB health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Should show: HealthCheckState = healthy

# Check EC2 instances are running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*elderping*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]'

# Check RDS is available
aws rds describe-db-instances \
  --db-instance-identifier elderping-prod \
  --query 'DBInstances[0].[DBInstanceStatus,DBInstanceClass]'
```

#### B. Configure Email Notifications

```bash
# SNS subscriptions require email confirmation
# Users will receive emails and must click "Confirm subscription"

# Verify subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw infra_alarms_topic_arn)
```

#### C. Deploy Application Code

```bash
# Push Docker image to ECR
# (Assuming you have built your Docker image)

ECR_URI="123456789012.dkr.ecr.us-east-1.amazonaws.com/elderping:latest"

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Tag your Docker image
docker tag elderping:latest $ECR_URI

# Push to ECR
docker push $ECR_URI

# Update EC2 Launch Template to use new image
# EC2 will auto-scale and pull the new image
```

#### D. Configure Application Environment

```bash
# Get secrets for application
aws secretsmanager get-secret-value \
  --secret-id elderping/rds/master

# Secrets are automatically injected into EC2 instances via:
# - IAM role permissions
# - Secrets Manager + KMS encryption
# - Environment variables set on launch
```

---

## 🔧 Manual AWS Console Steps Required

### 1. **Verify Route53 SSL Certificate**
   - Go to **AWS Certificate Manager** → Certificates
   - Find: `*.elderping.online` and `elderping.online`
   - Status should be "Issued"
   - If validation pending, check Route53 DNS records

### 2. **Enable SNS Email Subscriptions**
   - Go to **SNS** → Topics
   - Select each topic (reminders, caregiver-alerts, infra-alarms)
   - Check email addresses confirmed subscription

### 3. **Verify CloudTrail Logging**
   - Go to **CloudTrail** → Trails
   - Find: `elderping-cloudtrail`
   - Status should show "Logging" = Yes
   - Verify S3 bucket: `elderping-cloudtrail-logs`

### 4. **Configure CloudWatch Alarms**
   - Go to **CloudWatch** → Alarms
   - Verify alarms for:
     - EC2 High CPU
     - RDS Database Connections
     - ALB Unhealthy Targets
     - Lambda Errors
   - Ensure all alarms are set to "Enabled"

### 5. **RDS Initial Configuration**
   - Go to **RDS** → Databases
   - Find: `elderping-prod`
   - Create initial database and tables:
   ```sql
   CREATE DATABASE elderping;
   \c elderping;
   
   -- Create users table
   CREATE TABLE users (
       id SERIAL PRIMARY KEY,
       email VARCHAR(255) UNIQUE NOT NULL,
       phone_number VARCHAR(20),
       created_at TIMESTAMP DEFAULT NOW()
   );
   
   -- Create reminders table
   CREATE TABLE reminders (
       id SERIAL PRIMARY KEY,
       patient_id INTEGER REFERENCES users(id),
       medication_name VARCHAR(255),
       scheduled_time TIMESTAMP,
       notified BOOLEAN DEFAULT FALSE,
       active BOOLEAN DEFAULT TRUE,
       created_at TIMESTAMP DEFAULT NOW()
   );
   
   -- Add caregiver assignments table if needed
   ```

### 6. **Test Application Deployment**
   - Access application: `https://app.elderping.online`
   - Verify it loads (may get 502 if app not running yet)
   - Check EC2 instance logs: `/var/log/messages`
   - Use Systems Manager Session Manager to connect

### 7. **Configure Automated Backups**
   - Go to **RDS** → Databases → `elderping-prod`
   - Backup retention: Currently set to 7 days
   - Manual snapshots: Create one immediately after deployment
   - Enable automated minor version upgrades

### 8. **Set Up Password Manager**
   - Save all credentials from Secrets Manager:
     - RDS master password
     - JWT secret
     - SMTP credentials (if applicable)
   - Store in secure location (1Password, LastPass, etc.)

---

## 📊 Monitoring & Operations

### CloudWatch Dashboards
Create a custom dashboard in CloudWatch:
```bash
# Get key metrics
aws cloudwatch list-metrics --namespace "AWS/ApplicationELB"
aws cloudwatch list-metrics --namespace "AWS/RDS"
aws cloudwatch list-metrics --namespace "AWS/EC2"
```

### Health Checks
```bash
# Check application health
curl -I https://app.elderping.online

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Check RDS connection
aws rds describe-db-instances \
  --db-instance-identifier elderping-prod \
  --query 'DBInstances[0].DBInstanceStatus'
```

### Auto-Scaling Status
```bash
# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name elderping-prod-asg

# Current capacity
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names elderping-prod-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]'
```

### Lambda Execution
```bash
# View Lambda logs
aws logs tail /aws/lambda/elderping-prod-reminder --follow

# Manually invoke Lambda (for testing)
aws lambda invoke \
  --function-name elderping-prod-reminder \
  --payload '{}' \
  response.json
cat response.json
```

---

## 🧹 Cleanup & Destruction

### Delete All Infrastructure
```bash
# This deletes ALL resources - use with extreme caution!
cd environments/prod

terraform destroy

# Type "yes" to confirm
# This takes ~10 minutes

# Note: Some resources are protected (ALB, RDS, S3 backend)
# If destroy fails, manually delete:
# - S3 buckets (backend, logs, backups)
# - RDS snapshots
# - Route53 records
```

### Partial Cleanup
```bash
# Remove specific resources
terraform destroy -target=module.lambda
terraform destroy -target=module.eventbridge
terraform destroy -target=module.cloudwatch
```

---

## 🐛 Troubleshooting

### Issue: Terraform Init Fails
```
Error: Error configuring the backend "s3":
  bucket does not exist
```
**Solution**: Create the S3 backend bucket manually (see Pre-Deployment Requirements)

### Issue: Provider Authentication Failed
```
Error: error configuring AWS Provider:
  NoCredentialProviders
```
**Solution**: 
```bash
export AWS_ACCESS_KEY_ID="xxx"
export AWS_SECRET_ACCESS_KEY="xxx"
# OR
aws configure
```

### Issue: RDS Database Won't Connect
**Solution**:
- Check security group allows connection from EC2
- Verify RDS endpoint is correct
- Confirm database credentials in Secrets Manager
- Check RDS parameter group has correct settings

### Issue: Unhealthy ALB Targets
```bash
# Check EC2 instance health
aws ec2 describe-instances --filters "Name=tag:Name,Values=*elderping*"

# SSH to instance using Session Manager
aws ssm start-session --target i-1234567890abcdef0

# Inside instance, check application logs
tail -f /var/log/messages
docker ps  # if using Docker
```

### Issue: Lambda Function Not Executing
```bash
# Check EventBridge rule
aws events describe-rule --name elderping-prod-reminder-rule

# Check Lambda permissions
aws lambda get-policy --function-name elderping-prod-reminder

# Check Lambda logs
aws logs tail /aws/lambda/elderping-prod-reminder --follow
```

### Issue: SNS Notifications Not Received
- Check email addresses confirmed subscription
- Verify SNS topics exist: `aws sns list-topics`
- Check Lambda is publishing to correct topic ARN
- Look for delivery issues in SNS topic metrics

---

## 📈 Performance Tuning

### Auto-Scaling Configuration
```bash
# Current settings in terraform.tfvars:
asg_min     = 1
asg_desired = 2
asg_max     = 4

# To adjust:
# Edit terraform.tfvars
# Run: terraform apply
```

### RDS Performance
```bash
# Check slow queries
aws rds describe-db-parameters \
  --db-parameter-group-name elderping-pg15-params \
  --query 'Parameters[?ParameterName==`log_min_duration_statement`]'

# Enable query logging by setting to 0 (logs all queries)
# Edit rds module variable
```

### CloudFront Caching
Current settings:
- Static assets (/static/*): Cached indefinitely
- Dynamic content: No caching (TTL=0)

To adjust, edit `modules/cloudfront/main.tf`

---

## 🔄 Updating Infrastructure

### Update EC2 Instance Type
```bash
# 1. Edit terraform.tfvars
# ec2_instance_type = "t3.large"

# 2. Apply changes
terraform plan
terraform apply

# 3. Auto Scaling Group will:
#    - Create new instances with new type
#    - Terminate old instances
#    - Maintain desired capacity
```

### Update RDS Instance Class
```bash
# Edit terraform.tfvars
# rds_instance_class = "db.t3.large"

# Apply (will cause brief downtime)
terraform apply
```

### Update Application Image
```bash
# 1. Push new Docker image to ECR
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/elderping:v2.0

# 2. Edit terraform.tfvars
# image_tag = "v2.0"

# 3. Apply changes
terraform apply

# 4. Auto Scaling Group will replace instances
```

---

## 📚 Additional Documentation

### Module Details
- [VPC Module](../../modules/vpc/README.md)
- [RDS Module](../../modules/rds/README.md)
- [EC2 Module](../../modules/ec2/README.md)
- [Lambda Module](../../modules/lambda/README.md)
- [Networking & Security](../../modules/security-groups/README.md)

### AWS Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [Lambda VPC](https://docs.aws.amazon.com/lambda/latest/dg/vpc.html)

---

## ✅ Deployment Checklist

- [ ] AWS account created
- [ ] S3 backend bucket created
- [ ] DynamoDB locks table created
- [ ] Route53 hosted zone created and nameservers configured
- [ ] IAM user created with programmatic access
- [ ] AWS CLI configured
- [ ] Terraform installed (>= 1.7.0)
- [ ] Environment variables set (DB_USERNAME, DB_PASSWORD, JWT_SECRET)
- [ ] terraform init completed
- [ ] terraform plan reviewed
- [ ] terraform apply completed successfully
- [ ] Infrastructure verified in AWS Console
- [ ] SNS subscriptions confirmed via email
- [ ] RDS database tables created
- [ ] Docker image pushed to ECR
- [ ] Application tested at https://app.elderping.online
- [ ] CloudWatch alarms verified
- [ ] CloudTrail logging verified
- [ ] Backups configured and tested

---

## 📞 Support & Issues

For issues or questions:
1. Check [Troubleshooting](#-troubleshooting) section
2. Review Terraform logs: `TF_LOG=DEBUG terraform apply`
3. Check AWS CloudTrail for API errors
4. Review EC2 instance logs via Systems Manager Session Manager
5. Check Lambda CloudWatch logs for background job issues

---

## 🔐 Security Reminders

⚠️ **IMPORTANT**:
- Never commit `terraform.tfvars` with actual secrets to Git
- Always use environment variables for sensitive data
- Rotate secrets every 90 days
- Enable MFA on AWS account
- Regularly review IAM permissions
- Monitor CloudTrail logs for suspicious activity
- Keep Terraform and AWS CLI updated
- Use AWS Secrets Manager for all credentials
- Encrypt S3 backend bucket
- Enable versioning on state bucket

---

Generated: 2026-06-09
Infrastructure Project: ElderPing
Environment: Production
