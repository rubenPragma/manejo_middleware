data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

module "network_infra" {
  source = "./modules/network_infra"

  environment          = var.environment
  project_name         = var.project_name
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  http_cidr_blocks     = var.http_cidr_blocks
  ssh_cidr_blocks      = var.ssh_cidr_blocks
  office_cidr          = var.ssh_cidr_blocks[0]
  key_name             = var.key_name
  flow_logs_bucket_arn = aws_s3_bucket.tomcat_logs.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Module      = "network"
  }
}

module "tomcat_server" {
  source = "./modules/tomcat_server"

  environment   = var.environment
  project_name  = var.project_name
  region        = var.region
  vpc_id        = module.network_infra.vpc_id
  vpc_cidr      = var.vpc_cidr
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = module.network_infra.private_subnet_ids[0]
  bastion_cidr  = var.ssh_cidr_blocks[0]

  ssh_cidr_blocks  = var.ssh_cidr_blocks
  alb_arn          = aws_lb.tomcat.arn
  target_group_arn = aws_lb_target_group.tomcat.arn
  app_bucket_name  = aws_s3_bucket.tomcat_logs.id

  tomcat_version    = var.tomcat_version
  tomcat_port       = var.tomcat_port
  jvm_heap_size     = var.jvm_heap_size
  jvm_perm_size     = var.jvm_perm_size
  jvm_max_perm_size = var.jvm_max_perm_size
  jvm_gc_algorithm  = var.jvm_gc_algorithm

  database_endpoint = var.database_endpoint
  database_username = var.database_username
  database_password = var.database_password
  database_name     = var.database_name

  enable_monitoring    = var.enable_monitoring
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
  cpu_threshold_high   = var.scale_up_threshold
  cpu_threshold_low    = var.scale_down_threshold

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Module      = "tomcat"
  }
}

resource "aws_lb" "tomcat" {
  name               = "${var.project_name}-tomcat-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.network_infra.security_group_alb_id]
  subnets            = module.network_infra.public_subnet_ids

  enable_deletion_protection = var.lb_deletion_protection

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Name        = "${var.project_name}-tomcat-alb-${var.environment}"
  }
}

resource "aws_lb_target_group" "tomcat" {
  name     = "${var.project_name}-tomcat-tg-${var.environment}"
  port     = var.tomcat_port
  protocol = "HTTP"
  vpc_id   = module.network_infra.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 86400
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.tomcat.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat.arn
  }
}

resource "aws_lb_listener" "https" {
  count             = var.tomcat_ssl_enabled ? 1 : 0
  load_balancer_arn = aws_lb.tomcat.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.alb_ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat.arn
  }
}

resource "aws_lb_listener_rule" "static_content" {
  count = var.enable_static_content_cache ? 1 : 0

  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat.arn
  }

  condition {
    path_pattern {
      values = ["/*.css", "/*.js", "/*.jpg", "/*.png", "/*.ico", "/*.woff*"]
    }
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  count = var.enable_auto_scaling ? 1 : 0

  autoscaling_group_name = module.tomcat_server.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.tomcat.arn
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-tomcat-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  alarm_description   = "CPU utilization above threshold for Tomcat server"
  alarm_actions       = [aws_sns_topic.tomcat_alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.enable_auto_scaling ? module.tomcat_server.autoscaling_group_name : ""
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  count = var.enable_monitoring && var.enable_auto_scaling ? 1 : 0

  alarm_name          = "${var.project_name}-tomcat-cpu-low-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_cpu_low_threshold
  alarm_description   = "CPU utilization below threshold for Tomcat server scale-in"
  alarm_actions       = [aws_sns_topic.tomcat_alerts.arn]

  dimensions = {
    AutoScalingGroupName = module.tomcat_server.autoscaling_group_name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-tomcat-memory-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_memory_threshold
  alarm_description   = "Memory utilization above threshold for Tomcat server"
  alarm_actions       = [aws_sns_topic.tomcat_alerts.arn]

  dimensions = {
    AutoScalingGroupName = module.tomcat_server.autoscaling_group_name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_sns_topic" "tomcat_alerts" {
  name = "${var.project_name}-tomcat-alerts-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "tomcat_alerts_email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.tomcat_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_kms_key" "ebs_encryption" {
  description             = "KMS key for EBS encryption on Tomcat servers"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-policy"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 to use this key"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ec2.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Name        = "${var.project_name}-ebs-kms-${var.environment}"
  }
}

resource "aws_kms_alias" "ebs_encryption" {
  name          = "alias/${var.project_name}-ebs-${var.environment}"
  target_key_id = aws_kms_key.ebs_encryption.key_id
}

resource "aws_s3_bucket" "tomcat_logs" {
  bucket = "${var.project_name}-tomcat-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tomcat_logs" {
  bucket = aws_s3_bucket.tomcat_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "tomcat_logs" {
  bucket = aws_s3_bucket.tomcat_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ec2-ssm-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${var.project_name}-ec2-ssm-profile-${var.environment}"
  role = aws_iam_role.ec2_ssm_role.name

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}