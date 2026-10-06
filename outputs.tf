output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.network_infra.vpc_id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = module.network_infra.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas"
  value       = module.network_infra.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas"
  value       = module.network_infra.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "IPs de los NAT Gateways"
  value       = module.network_infra.nat_gateway_ips
}

output "alb_dns_name" {
  description = "Nombre DNS del Application Load Balancer"
  value       = aws_lb.tomcat.dns_name
}

output "alb_zone_id" {
  description = "Zone ID del ALB para Route 53"
  value       = aws_lb.tomcat.zone_id
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.tomcat.arn
}

output "alb_security_group_id" {
  description = "ID del security group del ALB"
  value       = module.network_infra.security_group_alb_id
}

output "target_group_arn" {
  description = "ARN del target group de Tomcat"
  value       = aws_lb_target_group.tomcat.arn
}

output "tomcat_security_group_id" {
  description = "ID del security group de Tomcat"
  value       = module.tomcat_server.security_group_id
}

output "autoscaling_group_name" {
  description = "Nombre del Auto Scaling Group"
  value       = var.enable_auto_scaling ? module.tomcat_server.autoscaling_group_name : ""
}

output "autoscaling_group_id" {
  description = "ID del Auto Scaling Group"
  value       = var.enable_auto_scaling ? module.tomcat_server.autoscaling_group_id : ""
}

output "instance_profile_name" {
  description = "Nombre del instance profile para SSM"
  value       = aws_iam_instance_profile.ec2_ssm_profile.name
}

output "kms_key_arn" {
  description = "ARN de la clave KMS para cifrado de EBS"
  value       = aws_kms_key.ebs_encryption.arn
}

output "kms_key_id" {
  description = "ID de la clave KMS para cifrado de EBS"
  value       = aws_kms_key.ebs_encryption.key_id
}

output "logs_bucket_name" {
  description = "Nombre del bucket S3 para logs de Tomcat"
  value       = aws_s3_bucket.tomcat_logs.id
}

output "sns_topic_arn" {
  description = "ARN del topic SNS para alertas"
  value       = aws_sns_topic.tomcat_alerts.arn
}

output "account_id" {
  description = "ID de la cuenta de AWS"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Región de AWS"
  value       = var.region
}

output "environment" {
  description = "Ambiente de despliegue"
  value       = var.environment
}

output "tomcat_url" {
  description = "URL pública del servidor Tomcat"
  value       = var.tomcat_ssl_enabled ? "https://${aws_lb.tomcat.dns_name}" : "http://${aws_lb.tomcat.dns_name}"
}

output "jvm_configuration" {
  description = "Configuración JVM aplicada al servidor Tomcat"
  value = {
    heap_size     = var.jvm_heap_size
    gc_algorithm  = var.jvm_gc_algorithm
    perm_size     = var.jvm_perm_size
    max_perm_size = var.jvm_max_perm_size
  }
  sensitive = false
}

output "tomcat_connector_config" {
  description = "Configuración del connector de Tomcat"
  value = {
    version     = var.tomcat_version
    port        = var.tomcat_port
    ssl_enabled = var.tomcat_ssl_enabled
  }
  sensitive = false
}