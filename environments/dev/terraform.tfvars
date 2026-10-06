environment  = "dev"
project_name = "banca-digital"
owner        = "cloud-ops-team"

# Configuración de red para desarrollo
vpc_cidr             = "10.0.0.0/16"
public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets_cidr = ["10.0.10.0/24", "10.0.20.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# Configuración de instancia EC2 para desarrollo
instance_type  = "t3.medium"
instance_count = 1
ami_id         = "ami-0c55b159cbfafe1f0"
key_name       = "banca-digital-dev-key"

# Configuración de Tomcat para desarrollo
tomcat_version     = "9.0.85"
tomcat_port        = 8080
tomcat_ssl_enabled = false
max_threads        = 150
min_spare_threads  = 25

# Configuración de JVM optimizada para desarrollo
jvm_heap_min          = "512m"
jvm_heap_max          = "1024m"
jvm_metaspacesize     = "128m"
jvm_max_metaspacesize = "256m"
jvm_gc_algorithm      = "G1GC"
jvm_gc_log_enabled    = true
jvm_gc_log_size       = "50m"
jvm_gc_log_max_files  = 5
jvm_extra_opts        = "-XX:+UseStringDeduplication -XX:+ParallelRefProcEnabled"
jvm_agents_enabled    = false

# Configuración de seguridad para desarrollo
allowed_ssh_cidr  = ["10.0.0.0/16"]
allowed_app_cidr  = ["10.0.0.0/16"]
ssh_port          = 22
enable_monitoring = true
enable_logging    = true

# Configuración de almacenamiento
root_volume_size = 20
data_volume_size = 30
volume_type      = "gp3"

# Configuración de costos y etiquetas
cost_center          = "CC-DEV-001"
enable_cost_alerts   = false
budget_limit_monthly = 100.0

# Configuración de alta disponibilidad para desarrollo
enable_health_checks   = true
health_check_interval  = 30
health_check_timeout   = 5
health_check_unhealthy = 3

# Valores para variables declaradas en variables.tf
region                      = "us-east-1"
jvm_heap_size               = "1024m"
jvm_perm_size               = "128m"
jvm_max_perm_size           = "256m"
asg_min_size                = 1
asg_max_size                = 2
asg_desired_capacity        = 1
enable_auto_scaling         = true
scale_up_threshold          = 70
scale_down_threshold        = 30
lb_deletion_protection      = false
enable_static_content_cache = false
alarm_cpu_threshold         = 80
alarm_cpu_low_threshold     = 20
alarm_memory_threshold      = 85
alert_email                 = ""
# Obligatorio cuando tomcat_ssl_enabled = true (ARN de un certificado ACM)
alb_ssl_certificate_arn = ""
database_endpoint       = "localhost"
database_username       = "tomcat"
database_name           = "banking"
database_instance_class = "db.t3.micro"
# database_password es sensible: se inyecta con la variable de entorno TF_VAR_database_password
