environment  = "prod"
project_name = "banca-digital"
owner        = "cloud-ops-team"

# Configuración de red para producción
vpc_cidr             = "10.2.0.0/16"
public_subnets_cidr  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnets_cidr = ["10.2.10.0/24", "10.2.20.0/24", "10.2.30.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Configuración de instancia EC2 para producción - optimizado para 10k req/min
instance_type           = "r6i.2xlarge"
instance_count          = 4
ami_id                  = "ami-0c55b159cbfafe1f0"
key_name                = "banca-digital-prod-key"
tenancy                 = "default"
placement_group_enabled = true

# Configuración de Tomcat para producción
tomcat_version        = "9.0.85"
tomcat_port           = 8080
tomcat_ssl_enabled    = true
tomcat_ssl_port       = 8443
max_threads           = 800
min_spare_threads     = 100
connection_timeout    = 10000
max_connections       = 20000
acceptor_thread_count = 4
poller_thread_count   = 4
enable_compression    = true
compression_min_size  = 1024

# Configuración de JVM optimizada para producción - 10k req/min
jvm_heap_min             = "4096m"
jvm_heap_max             = "8192m"
jvm_metaspacesize        = "512m"
jvm_max_metaspacesize    = "1024m"
jvm_gc_algorithm         = "ZGC"
jvm_gc_log_enabled       = true
jvm_gc_log_size          = "200m"
jvm_gc_log_max_files     = 20
jvm_extra_opts           = "-XX:+UseStringDeduplication -XX:+ParallelRefProcEnabled -XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:NativeMemoryTracking=summary -XX:+AlwaysPreTouch -XX:+UseLargePages -XX:+UseTransparentHugePages"
jvm_agents_enabled       = true
jvm_heap_dump_enabled    = true
jvm_heap_dump_path       = "/opt/tomcat/logs"
jvm_heap_dump_on_oom     = true
jvm_remote_debug_enabled = false

# Configuración de seguridad para producción - principio de menor privilegio
allowed_ssh_cidr       = ["10.2.0.0/16"]
allowed_app_cidr       = ["10.2.0.0/16", "10.3.0.0/16"]
ssh_port               = 22
ssh_access_cidr        = ["10.2.0.0/24"]
enable_monitoring      = true
enable_logging         = true
enable_audit_logging   = true
enable_waf_protection  = true
enable_ddos_protection = true

# Configuración de almacenamiento de alto rendimiento
root_volume_size     = 50
data_volume_size     = 100
volume_type          = "gp3"
io1_iops             = 3000
io1_throughput       = 125
enable_ebs_optimized = true

# Configuración de costos y etiquetas
cost_center          = "CC-PROD-001"
enable_cost_alerts   = true
budget_limit_monthly = 5000.0
cost_alert_threshold = 0.75
cost_tags_enabled    = true

# Configuración de alta disponibilidad para producción
enable_health_checks   = true
health_check_interval  = 10
health_check_timeout   = 3
health_check_unhealthy = 2
health_check_healthy   = 2
enable_load_balancer   = true
lb_type                = "application"
lb_deletion_protection = true
lb_ssl_policy          = "ELBSecurityPolicy-2016-08"
enable_cross_zone_lb   = true

# Configuración de auto-scaling para producción
enable_auto_scaling   = true
asg_min_size          = 4
asg_max_size          = 12
asg_desired_capacity  = 4
scaling_cooldown      = 300
scaling_warmup        = 120
scale_up_threshold    = 70
scale_down_threshold  = 30
scale_up_adjustment   = 2
scale_down_adjustment = 1

# Configuración de recuperación ante desastres
enable_backup            = true
backup_retention_days    = 30
backup_schedule          = "cron(0 5 ? * * *)"
rto_minutes              = 30
rpo_minutes              = 15
enable_multi_az_recovery = true

# Valores para variables declaradas en variables.tf
region                      = "us-east-1"
jvm_heap_size               = "8192m"
jvm_perm_size               = "512m"
jvm_max_perm_size           = "1024m"
enable_static_content_cache = true
alarm_cpu_threshold         = 75
alarm_cpu_low_threshold     = 25
alarm_memory_threshold      = 85
alert_email                 = ""
# Obligatorio cuando tomcat_ssl_enabled = true (ARN de un certificado ACM)
alb_ssl_certificate_arn = ""
database_endpoint       = "localhost"
database_username       = "tomcat"
database_name           = "banking"
database_instance_class = "db.r6g.large"
# database_password es sensible: se inyecta con la variable de entorno TF_VAR_database_password
