# Variables específicas para el módulo de servidor Tomcat
# Configuración detallada del servidor de aplicación y sus recursos asociados

variable "project_name" {
  description = "Nombre del proyecto para etiquetado"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue (dev, qa, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se desplegará el servidor"
  type        = string
}

variable "region" {
  description = "Región de AWS (principal del servicio de CloudWatch Logs en la bucket policy)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC desde el que se permite tráfico a Tomcat"
  type        = string
}

variable "bastion_cidr" {
  description = "CIDR desde el que se permite SSH a las instancias"
  type        = string
}

variable "subnet_id" {
  description = "ID de la subred para el launch template y el Auto Scaling Group"
  type        = string
}

variable "ami_id" {
  description = "ID de la AMI para las instancias Tomcat"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para el servidor Tomcat"
  type        = string
}

variable "key_name" {
  description = "Nombre de la clave SSH para acceder a las instancias"
  type        = string
}

variable "app_bucket_name" {
  description = "Nombre del bucket S3 al que las instancias tienen acceso de lectura/escritura"
  type        = string
}

variable "asg_min_size" {
  description = "Número mínimo de instancias en el Auto Scaling Group"
  type        = number
}

variable "asg_max_size" {
  description = "Número máximo de instancias en el Auto Scaling Group"
  type        = number
}

variable "asg_desired_capacity" {
  description = "Número deseado de instancias en el Auto Scaling Group"
  type        = number
}

variable "cpu_threshold_high" {
  description = "Porcentaje de CPU que dispara el scale-up"
  type        = number
}

variable "cpu_threshold_low" {
  description = "Porcentaje de CPU que dispara el scale-down"
  type        = number
}

variable "enable_monitoring" {
  description = "Crear la alarma de memoria del ASG"
  type        = bool
}

variable "tomcat_version" {
  description = "Versión de Apache Tomcat a instalar"
  type        = string
}

variable "jvm_heap_size" {
  description = "Tamaño máximo del heap de la JVM (ej. 2048m)"
  type        = string
}

variable "jvm_perm_size" {
  description = "Tamaño de la memoria permanente de la JVM (ej. 256m)"
  type        = string
}

variable "jvm_max_perm_size" {
  description = "Tamaño máximo de la memoria permanente de la JVM (ej. 512m)"
  type        = string
}

variable "jvm_gc_algorithm" {
  description = "Algoritmo de garbage collection a usar (ej. UseG1GC)"
  type        = string
}

variable "alb_arn" {
  description = "ARN del Application Load Balancer"
  type        = string
}

variable "target_group_arn" {
  description = "ARN del Target Group para el ALB"
  type        = string
}

variable "database_endpoint" {
  description = "Endpoint de la base de datos RDS"
  type        = string
}

variable "database_username" {
  description = "Usuario para la base de datos"
  type        = string
}

variable "database_password" {
  description = "Contraseña para la base de datos"
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos"
  type        = map(string)
  default     = {}
}

# Validación de parámetros para optimización de JVM
locals {
  # Validación de parámetros de JVM
  validate_jvm_heap_size     = can(regex("^[0-9]+[mMgG]$", var.jvm_heap_size)) ? true : "Tamaño de heap JVM debe terminar con m, M, g o G"
  validate_jvm_perm_size     = can(regex("^[0-9]+[mMgG]$", var.jvm_perm_size)) ? true : "Tamaño de perm gen JVM debe terminar con m, M, g o G"
  validate_jvm_max_perm_size = can(regex("^[0-9]+[mMgG]$", var.jvm_max_perm_size)) ? true : "Tamaño máximo de perm gen JVM debe terminar con m, M, g o G"

  # Validación de algoritmo de garbage collection
  valid_gc_algorithms = [
    "UseSerialGC",
    "UseParallelGC",
    "UseConcMarkSweepGC",
    "UseG1GC"
  ]
  validate_jvm_gc_algorithm = contains(local.valid_gc_algorithms, var.jvm_gc_algorithm) ? true : "Algoritmo de GC no válido"

  # Validación de puertos
  validate_tomcat_port = var.tomcat_port == 8080 || var.tomcat_port == 80 || var.tomcat_port == 443 ? true : "Puerto de Tomcat no válido"
}

variable "tomcat_port" {
  description = "Puerto donde escucha el servidor Tomcat"
  type        = number
  default     = 8080
}

variable "ssh_cidr_blocks" {
  description = "Bloques CIDR permitidos para acceso SSH"
  type        = list(string)
}