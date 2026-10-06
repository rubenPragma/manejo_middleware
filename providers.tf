# Configuración de proveedores para Terraform
# Define los proveedores necesarios y sus versiones

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Proveedor AWS principal
provider "aws" {
  region = var.region
  default_tags {
    tags = merge(
      {
        "Project"     = var.project_name
        "Environment" = var.environment
        "ManagedBy"   = "Terraform"
      },
      var.tags
    )
  }
}

# Backend remoto para el estado de Terraform (se configurará en backend.tf)
# La configuración específica del backend se define en backend.tf
# para permitir diferentes configuraciones por ambiente

# Validación de variables para asegurar configuraciones válidas
locals {
  validate_instance_type = contains([
    "t3.micro", "t3.small", "t3.medium", "t3.large",
    "m5.large", "m5.xlarge", "m5.2xlarge", "c5.large", "c5.xlarge"
  ], var.instance_type) ? true : "Tipo de instancia no soportado"

  validate_tomcat_version = contains([
    "8.5.60", "9.0.45", "10.0.8"
  ], var.tomcat_version) ? true : "Versión de Tomcat no soportada"

  validate_environment = contains([
    "dev", "qa", "prod"
  ], var.environment) ? true : "Ambiente no válido"

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
}