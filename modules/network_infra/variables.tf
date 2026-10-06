# Variables para el módulo de infraestructura de red
# Configuración de VPC, subredes, NAT Gateway y otros componentes de red

variable "project_name" {
  description = "Nombre del proyecto para etiquetado"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue (dev, qa, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR para la VPC"
  type        = string
}

variable "public_subnets_cidr" {
  description = "Lista de bloques CIDR para subredes públicas"
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "Lista de bloques CIDR para subredes privadas"
  type        = list(string)
}

variable "availability_zones" {
  description = "Lista de zonas de disponibilidad para distribuir los recursos"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway para salida a Internet desde subredes privadas"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Usar un único NAT Gateway para todas las subredes privadas (para ahorro de costos)"
  type        = bool
  default     = true
}

variable "one_nat_gateway_per_az" {
  description = "Crear un NAT Gateway por zona de disponibilidad (alta disponibilidad)"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Habilitar DNS hostnames en la VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Habilitar soporte DNS en la VPC"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos de red"
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "Región de AWS (para los service names de los VPC endpoints)"
  type        = string
}

variable "office_cidr" {
  description = "CIDR desde el que se permite SSH al bastion"
  type        = string
}

variable "key_name" {
  description = "Nombre del key pair para el bastion"
  type        = string
}

variable "flow_logs_bucket_arn" {
  description = "ARN del bucket S3 destino de los VPC Flow Logs"
  type        = string
}

variable "enable_https" {
  description = "Crear el listener HTTPS en el ALB del módulo"
  type        = bool
  default     = false
}

variable "ssl_certificate_arn" {
  description = "ARN del certificado ACM para el listener HTTPS"
  type        = string
  default     = null
}

variable "enable_bastion" {
  description = "Crear la instancia bastion en la subred pública"
  type        = bool
  default     = false
}

variable "bastion_ami" {
  description = "AMI del bastion (requerida si enable_bastion = true)"
  type        = string
  default     = null
}

variable "bastion_instance_type" {
  description = "Tipo de instancia del bastion"
  type        = string
  default     = "t3.micro"
}

variable "enable_private_dns" {
  description = "Crear la zona privada de Route 53"
  type        = bool
  default     = false
}

variable "http_cidr_blocks" {
  description = "Bloques CIDR permitidos para acceso HTTP/HTTPS"
  type        = list(string)
}

variable "ssh_cidr_blocks" {
  description = "Bloques CIDR permitidos para acceso SSH"
  type        = list(string)
}

# Validación de parámetros de red
locals {
  # Validación de CIDR blocks
  validate_vpc_cidr = can(cidrhost(var.vpc_cidr, 0)) ? true : "CIDR de VPC no válido"

  validate_public_subnets = alltrue([
    for cidr in var.public_subnets_cidr : can(cidrhost(cidr, 0))
  ]) ? true : "Uno o más CIDR de subredes públicas no válidos"

  validate_private_subnets = alltrue([
    for cidr in var.private_subnets_cidr : can(cidrhost(cidr, 0))
  ]) ? true : "Uno o más CIDR de subredes privadas no válidos"

  # Validación de zonas de disponibilidad
  validate_az_count = length(var.availability_zones) >= 2 ? true : "Se requieren al menos 2 zonas de disponibilidad"

  # Validación de NAT Gateway
  validate_nat_config = !(var.single_nat_gateway && var.one_nat_gateway_per_az) ? true : "No se puede configurar single_nat_gateway y one_nat_gateway_per_az simultáneamente"

  # Validación de bloques CIDR para acceso
  validate_http_cidr = alltrue([
    for cidr in var.http_cidr_blocks : can(cidrhost(cidr, 0))
  ]) ? true : "Uno o más CIDR de acceso HTTP no válidos"

  validate_ssh_cidr = alltrue([
    for cidr in var.ssh_cidr_blocks : can(cidrhost(cidr, 0))
  ]) ? true : "Uno o más CIDR de acceso SSH no válidos"
}