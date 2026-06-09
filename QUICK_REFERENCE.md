# Quick Reference Guide

## 🏃 5-Minute Setup Summary

### Prerequisites (One-Time Setup)
```bash
# 1. Create Terraform backend (AWS Console)
# See DEPLOYMENT_GUIDE.md → Pre-Deployment Requirements → Step 1

# 2. Create Route53 hosted zone
aws route53 create-hosted-zone --name elderping.online --caller-reference $(date +%s)

# 3. Create ECR and push image
aws ecr create-repository --repository-name elderping
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/elderping:latest
```

### Deployment (First Time)
```bash
# 1. Set environment variables
export AWS_ACCESS_KEY_ID="xxx"
export AWS_SECRET_ACCESS_KEY="xxx"
export TF_VAR_db_username="elderping_admin"
export TF_VAR_db_password="$(openssl rand -base64 32)"
export TF_VAR_jwt_secret="$(openssl rand -hex 32)"

# 2. Initialize
cd environments/prod
terraform init

# 3. Plan
terraform plan -out=tfplan

# 4. Apply
terraform apply tfplan

# ⏱️ Wait 25-40 minutes for RDS to provision

# 5. Get outputs
terraform output
```

### Post-Deploy
```bash
# 1. Confirm SNS subscriptions (check emails)

# 2. Create RDS database tables (see DEPLOYMENT_GUIDE.md → Step 7D)

# 3. Test application
curl -I https://app.elderping.online

# 4. Monitor Lambda
aws logs tail /aws/lambda/elderping-prod-reminder --follow
```

---

## 🔍 Common Commands

### Check Infrastructure Status
```bash
# EC2 instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=*elderping*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]'

# RDS
aws rds describe-db-instances --db-instance-identifier elderping-prod \
  --query 'DBInstances[0].[DBInstanceStatus,DBInstanceClass,AvailabilityZone]'

# ALB targets
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)

# Auto-scaling group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names elderping-prod-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].InstanceId]'
```

### View Logs
```bash
# Application logs
aws logs tail /aws/elasticloadbalancing/app/elderping-prod-alb --follow

# RDS logs
aws rds describe-db-log-files --db-instance-identifier elderping-prod

# Lambda logs
aws logs tail /aws/lambda/elderping-prod-reminder --follow

# VPC endpoints
aws ec2 describe-vpc-endpoints --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
```

### Manage Secrets
```bash
# Get RDS credentials
aws secretsmanager get-secret-value --secret-id elderping/rds/master

# Get JWT secret
aws secretsmanager get-secret-value --secret-id elderping/jwt-secret

# Rotate secret
aws secretsmanager rotate-secret --secret-id elderping/rds/master
```

### Scale Application
```bash
# Increase desired capacity
aws autoscaling set-desired-capacity --auto-scaling-group-name elderping-prod-asg \
  --desired-capacity 4

# Current ASG config
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names elderping-prod-asg
```

### CloudWatch Alarms
```bash
# List all alarms
aws cloudwatch describe-alarms --query 'MetricAlarms[*].[AlarmName,StateValue]'

# Get alarm details
aws cloudwatch describe-alarms --alarm-names "elderping-prod-ec2-cpu-high"

# Manually trigger alarm
aws cloudwatch set-alarm-state --alarm-name "elderping-prod-test" --state-value ALARM
```

---

## 📝 Configuration Files Reference

| File | Purpose | Editable? |
|------|---------|-----------|
| `environments/prod/main.tf` | Module definitions | ❌ Usually not |
| `environments/prod/variables.tf` | Input variables | ✅ Add new vars here |
| `environments/prod/terraform.tfvars` | Variable values | ✅ **Primary config file** |
| `environments/prod/output.tf` | Outputs | ❌ Usually not |
| `modules/*/main.tf` | Resource definitions | ⚠️ Only if changing architecture |
| `modules/*/variables.tf` | Module inputs | ⚠️ Only if changing architecture |
| `modules/*/output.tf` | Module outputs | ❌ Usually not |

**Most Common Edits**:
1. `terraform.tfvars` - Update instance types, sizes, tags, etc.
2. `main.tf` - Add/remove modules or change module versions

---

## 🔧 Update Procedures

### Change Instance Type
```bash
# 1. Edit terraform.tfvars
ec2_instance_type = "t3.large"  # Was "t3.medium"

# 2. Apply
terraform plan
terraform apply

# No downtime - ASG handles graceful replacement
```

### Change RDS Size
```bash
# 1. Edit terraform.tfvars
rds_instance_class = "db.t3.large"  # Was "db.t3.medium"

# 2. Apply
terraform plan
terraform apply

# Brief downtime during scaling (1-2 minutes)
```

### Update Application Image
```bash
# 1. Push new image
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/elderping:v2.0

# 2. Update terraform.tfvars
image_tag = "v2.0"

# 3. Apply
terraform apply

# ASG will replace instances gradually (rolling deployment)
```

### Scale Out (More Instances)
```bash
# 1. Edit terraform.tfvars
asg_min     = 2
asg_desired = 4
asg_max     = 6

# 2. Apply
terraform apply
```

---

## 🚨 Emergency Procedures

### Kill Runaway Lambda
```bash
# Disable EventBridge rule
aws events disable-rule --name elderping-prod-reminder-rule

# Check logs for errors
aws logs tail /aws/lambda/elderping-prod-reminder --follow

# Fix code, re-enable
aws events enable-rule --name elderping-prod-reminder-rule
```

### Emergency Failover (RDS)
```bash
# Automatic - no action needed (Multi-AZ enabled)
# Monitor
aws rds describe-db-instances --db-instance-identifier elderping-prod \
  --query 'DBInstances[0].MultiAZ'
```

### Remove Broken Instance
```bash
# Get instance ID
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names elderping-prod-asg \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

# Terminate (ASG will launch replacement)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Monitor ASG
watch 'aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names elderping-prod-asg'
```

### Temporarily Disable Auto-Scaling
```bash
# Suspend scaling processes
aws autoscaling suspend-processes --auto-scaling-group-name elderping-prod-asg

# Resume later
aws autoscaling resume-processes --auto-scaling-group-name elderping-prod-asg
```

---

## 🧪 Testing Commands

### Test ALB Health
```bash
curl -v http://$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $(terraform output -raw alb_arn) \
  --query 'LoadBalancers[0].DNSName' --output text)
```

### Test RDS Connection
```bash
# From EC2 instance (via Session Manager)
aws ssm start-session --target <instance-id>

# Inside instance
psql -h $(terraform output -raw rds_address) -U elderping_admin -d elderping
```

### Test Lambda Manually
```bash
aws lambda invoke \
  --function-name elderping-prod-reminder \
  --payload '{}' \
  response.json

cat response.json
```

### Test SNS Publishing
```bash
aws sns publish \
  --topic-arn $(terraform output -raw infra_alarms_topic_arn) \
  --subject "Test Alarm" \
  --message "This is a test notification"
```

### Connect to EC2 Instance
```bash
# List instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=*elderping*" \
  --query 'Reservations[*].Instances[*].InstanceId'

# Start session (no SSH key needed)
aws ssm start-session --target <instance-id>

# Inside instance
sudo -su ec2-user
docker ps
docker logs <container-id>
```

---

## 📊 Monitoring Dashboard

Create this in CloudWatch Console for real-time monitoring:

**Add these metrics**:
- ALB: TargetResponseTime, HealthyHostCount, UnhealthyHostCount
- EC2: CPUUtilization, NetworkIn, NetworkOut
- RDS: DatabaseConnections, CPUUtilization, DBLoad
- Lambda: Invocations, Errors, Duration

**Add these alarms**:
- EC2 CPU > 80%
- RDS Connections > 80 of max
- ALB Unhealthy Targets > 0
- Lambda Errors > 5/hour

---

## 📋 Maintenance Checklist

### Weekly
- [ ] Check CloudWatch alarms for any failures
- [ ] Review ALB access logs for suspicious requests
- [ ] Check RDS storage usage

### Monthly
- [ ] Review and download CloudTrail logs
- [ ] Verify backups are working
- [ ] Update Terraform and AWS CLI
- [ ] Rotate secrets (if not automatic)

### Quarterly
- [ ] Review security group rules
- [ ] Audit IAM permissions
- [ ] Test disaster recovery procedures
- [ ] Update EC2 AMI to latest

### Annually
- [ ] Full infrastructure audit
- [ ] Load testing with increased traffic
- [ ] Review and update documentation

---

## 🎓 Useful Links

```bash
# Open AWS Console for your resources
# Terraform outputs these URLs:

# Application
https://app.elderping.online

# ALB DNS (for internal testing)
$(terraform output alb_dns_name)

# CloudFront
$(terraform output cloudfront_domain_name)

# RDS endpoint
$(terraform output rds_endpoint)
```

### AWS Console Shortcuts
```
VPC: https://console.aws.amazon.com/vpc/
RDS: https://console.aws.amazon.com/rds/
EC2: https://console.aws.amazon.com/ec2/
Lambda: https://console.aws.amazon.com/lambda/
CloudWatch: https://console.aws.amazon.com/cloudwatch/
Route53: https://console.aws.amazon.com/route53/
```

---

## 🆘 When Something Goes Wrong

1. **Check the logs**
   ```bash
   terraform apply 2>&1 | tee apply.log
   ```

2. **Enable debug logging**
   ```bash
   export TF_LOG=DEBUG
   terraform apply
   ```

3. **Validate configuration**
   ```bash
   terraform validate
   terraform fmt -check
   ```

4. **Check AWS service limits**
   ```bash
   # AWS Trusted Advisor (AWS Console)
   ```

5. **Review recent API calls**
   ```bash
   # CloudTrail (AWS Console)
   ```

6. **Look at infrastructure logs**
   ```bash
   aws logs describe-log-groups
   aws logs tail /path/to/log/group --follow
   ```

---

## 💾 Backup & Restore

### Manual RDS Backup
```bash
aws rds create-db-snapshot \
  --db-instance-identifier elderping-prod \
  --db-snapshot-identifier elderping-prod-backup-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots --db-instance-identifier elderping-prod
```

### Export State Locally
```bash
# Backup current state
terraform state pull > terraform.state.backup

# List state resources
terraform state list

# Inspect resource
terraform state show module.rds.aws_db_instance.main
```

### Restore from Snapshot
```bash
# Detailed procedures in AWS RDS documentation
# Not recommended for quick restore - better to use Multi-AZ failover
```

---

## 📞 Troubleshooting by Error

### "Backend S3 bucket does not exist"
```bash
# Create bucket and DynamoDB table (see DEPLOYMENT_GUIDE.md)
```

### "Target group has no healthy targets"
```bash
# Check EC2 instance health
aws elbv2 describe-target-health --target-group-arn <arn>

# SSH to instance and check application
aws ssm start-session --target <instance-id>
sudo docker logs <container-id>
```

### "RDS connection refused"
```bash
# Check security group allows traffic
aws ec2 describe-security-groups --group-ids <sg-id>

# Test connectivity from EC2
aws ssm start-session --target <instance-id>
psql -h <rds-endpoint> -U elderping_admin  
```

### "Lambda timeout"
```bash
# Increase timeout in lambda module
timeout = 60  # seconds

# Check VPC endpoint connectivity
aws ec2 describe-vpc-endpoints --filter "Name=vpc-id,Values=<vpc-id>"
```

### "ACM certificate pending validation"
```bash
# Route53 should auto-create validation records
# If not, manually create DNS validation records in Route53

# Check status
aws acm describe-certificate --certificate-arn <arn>
```

---

## 🔐 Credentials Management

```bash
# Never commit secrets!
git add .gitignore
echo "terraform.tfvars" >> .gitignore
echo "*.tfvars" >> .gitignore
git add .gitignore && git commit -m "Add secrets to gitignore"

# Always use environment variables
export TF_VAR_db_password="secret"

# Store securely
# AWS: Secrets Manager ✓ (already implemented)
# Local: 1Password, LastPass, pass
# CI/CD: GitHub Secrets, GitLab CI/CD Variables
```

---

Generated: 2026-06-09
Last Updated: Quick Reference v1.0
