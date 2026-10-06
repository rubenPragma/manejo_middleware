output "security_group_id" {
  description = "ID del security group del servidor Tomcat"
  value       = aws_security_group.tomcat_sg.id
}

output "autoscaling_group_name" {
  description = "Nombre del Auto Scaling Group de Tomcat"
  value       = aws_autoscaling_group.tomcat_asg.name
}

output "autoscaling_group_id" {
  description = "ID del Auto Scaling Group de Tomcat"
  value       = aws_autoscaling_group.tomcat_asg.id
}

output "autoscaling_group_arn" {
  description = "ARN del Auto Scaling Group de Tomcat"
  value       = aws_autoscaling_group.tomcat_asg.arn
}

output "launch_template_id" {
  description = "ID del Launch Template de Tomcat"
  value       = aws_launch_template.tomcat_lt.id
}

output "instance_profile_name" {
  description = "Nombre del perfil de instancia IAM"
  value       = aws_iam_instance_profile.tomcat_profile.name
}

output "instance_role_name" {
  description = "Nombre del rol de instancia IAM"
  value       = aws_iam_role.tomcat_instance_role.name
}

output "logs_bucket_name" {
  description = "Nombre del bucket de logs de Tomcat"
  value       = aws_s3_bucket.tomcat_logs.id
}

output "logs_bucket_arn" {
  description = "ARN del bucket de logs de Tomcat"
  value       = aws_s3_bucket.tomcat_logs.arn
}

output "scale_up_policy_arn" {
  description = "ARN de la política de scale-up del ASG"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_arn" {
  description = "ARN de la política de scale-down del ASG"
  value       = aws_autoscaling_policy.scale_down.arn
}