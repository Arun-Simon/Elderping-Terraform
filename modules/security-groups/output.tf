output "alb_sg_id"           { value = aws_security_group.alb.id }
output "ec2_sg_id"           { value = aws_security_group.ec2.id }
output "rds_sg_id"           { value = aws_security_group.rds.id }
output "vpc_endpoints_sg_id" { value = aws_security_group.vpc_endpoints.id }
output "lambda_sg_id"        { value = aws_security_group.lambda.id }