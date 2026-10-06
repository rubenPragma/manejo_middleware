output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas"
  value       = module.vpc.private_subnets
}

output "private_subnet_arns" {
  description = "ARNs de las subredes privadas para conexiones internas"
  value       = [for subnet in module.vpc.private_subnet_arns : subnet]
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "Nombre DNS del ALB para acceso externo"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID del ALB para configuración de Route 53"
  value       = aws_lb.main.zone_id
}

output "alb_target_group_arn" {
  description = "ARN del target group del ALB para registrar instancias Tomcat"
  value       = aws_lb_target_group.tomcat.arn
}

output "security_group_alb_id" {
  description = "ID del security group del ALB"
  value       = aws_security_group.alb_sg.id
}

output "nat_gateway_ips" {
  description = "IPs elásticas de los NAT Gateways para salida a internet"
  value       = [for ngw in aws_nat_gateway.main : ngw.public_ip]
}

output "igw_id" {
  description = "ID del Internet Gateway para conectividad pública"
  value       = module.vpc.igw_id
}

output "public_route_table_id" {
  description = "ID de la tabla de rutas pública"
  value       = module.vpc.public_route_table_ids[0]
}

output "private_route_table_ids" {
  description = "IDs de las tablas de rutas privadas por AZ"
  value       = module.vpc.private_route_table_ids
}