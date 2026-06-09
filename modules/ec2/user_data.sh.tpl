#!/bin/bash
set -euxo pipefail

REGION="${region}"
PROJECT="${project}"

yum update -y
yum install -y jq awscli docker
systemctl enable docker && systemctl start docker
usermod -aG docker ec2-user

mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

yum install -y amazon-cloudwatch-agent amazon-ssm-agent
systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent

RDS_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "${rds_master_secret_arn}" --region "$REGION" \
  --query SecretString --output text)
DB_USER=$(echo "$RDS_SECRET" | jq -r '.username')
DB_PASS=$(echo "$RDS_SECRET" | jq -r '.password')

JWT_SECRET_VAL=$(aws secretsmanager get-secret-value \
  --secret-id "${jwt_secret_arn}" --region "$REGION" \
  --query SecretString --output text | jq -r '.jwt_secret')

SMTP_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "${smtp_secret_arn}" --region "$REGION" \
  --query SecretString --output text)
SMTP_HOST=$(echo "$SMTP_SECRET" | jq -r '.smtp_host')
SMTP_PORT=$(echo "$SMTP_SECRET" | jq -r '.smtp_port')
SMTP_USER=$(echo "$SMTP_SECRET" | jq -r '.smtp_username')
SMTP_PASS=$(echo "$SMTP_SECRET" | jq -r '.smtp_password')

mkdir -p /opt/elderping
cat > /opt/elderping/.env <<EOF
DB_HOST=${rds_endpoint}
DB_PORT=5432
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
USERS_DB_NAME=users_db
HEALTH_DB_NAME=health_db
REMINDER_DB_NAME=reminder_db
ALERT_DB_NAME=alert_db
JWT_SECRET=$JWT_SECRET_VAL
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USERNAME=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASS
AWS_REGION=$REGION
S3_BUCKET=${s3_bucket}
EOF
chmod 600 /opt/elderping/.env

cat > /opt/elderping/docker-compose.yml <<'COMPOSE'
version: "3.9"
services:
  ui-service:
    image: ${ecr_registry}/elderping/ui-service:${image_tag}
    ports: ["80:80"]
    env_file: .env
    restart: unless-stopped
    logging:
      driver: awslogs
      options:
        awslogs-region: ${region}
        awslogs-group: ${log_group}
        awslogs-stream-prefix: ui-service
  auth-service:
    image: ${ecr_registry}/elderping/auth-service:${image_tag}
    expose: ["3001"]
    env_file: .env
    restart: unless-stopped
    environment: [DB_NAME=users_db]
    logging:
      driver: awslogs
      options:
        awslogs-region: ${region}
        awslogs-group: ${log_group}
        awslogs-stream-prefix: auth-service
  health-service:
    image: ${ecr_registry}/elderping/health-service:${image_tag}
    expose: ["3002"]
    env_file: .env
    restart: unless-stopped
    environment: [DB_NAME=health_db]
    logging:
      driver: awslogs
      options:
        awslogs-region: ${region}
        awslogs-group: ${log_group}
        awslogs-stream-prefix: health-service
  reminder-service:
    image: ${ecr_registry}/elderping/reminder-service:${image_tag}
    expose: ["3003"]
    env_file: .env
    restart: unless-stopped
    environment: [DB_NAME=reminder_db]
    logging:
      driver: awslogs
      options:
        awslogs-region: ${region}
        awslogs-group: ${log_group}
        awslogs-stream-prefix: reminder-service
  alert-service:
    image: ${ecr_registry}/elderping/alert-service:${image_tag}
    expose: ["3004"]
    env_file: .env
    restart: unless-stopped
    environment: [DB_NAME=alert_db]
    logging:
      driver: awslogs
      options:
        awslogs-region: ${region}
        awslogs-group: ${log_group}
        awslogs-stream-prefix: alert-service
COMPOSE

cd /opt/elderping
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ecr_registry}"
docker-compose pull
docker-compose up -d