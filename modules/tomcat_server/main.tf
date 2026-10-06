locals {
  name_prefix = "tomcat-${var.environment}"
  common_tags = {
    Environment = var.environment
    Project     = "banca-digital"
    ManagedBy   = "terraform"
    Owner       = "cloudops-team"
  }
}

resource "aws_security_group" "tomcat_sg" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for Tomcat server - allows HTTP and SSH access"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP access from ALB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTPS access from ALB"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SSH access from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
  })
}

resource "aws_iam_role" "tomcat_instance_role" {
  name = "${local.name_prefix}-instance-role"

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

  tags = local.common_tags
}

resource "aws_iam_role_policy" "tomcat_ssm_policy" {
  name = "${local.name_prefix}-ssm-policy"
  role = aws_iam_role.tomcat_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchListForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocumentParameters",
          "ssm:GetManifest",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply",
          "ssm:ExecuteScript",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:SendCommand"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.app_bucket_name}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "tomcat_profile" {
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.tomcat_instance_role.name

  tags = local.common_tags
}

resource "aws_launch_template" "tomcat_lt" {
  name_prefix   = local.name_prefix
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.tomcat_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.tomcat_sg.id]
    subnet_id                   = var.subnet_id
  }

  user_data = base64encode(templatefile("${path.module}/../../scripts/configure_tomcat.sh", {
    environment      = var.environment
    jvm_heap_size    = var.jvm_heap_size
    jvm_gc_algorithm = var.jvm_gc_algorithm
    app_bucket       = var.app_bucket_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-instance"
    })
  }

  metadata_options {
    http_endpoint          = "enabled"
    http_tokens            = "required"
    instance_metadata_tags = "enabled"
  }

  monitoring {
    enabled = true
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_autoscaling_group" "tomcat_asg" {
  name                      = "${local.name_prefix}-asg"
  vpc_zone_identifier       = [var.subnet_id]
  desired_capacity          = var.asg_desired_capacity
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.tomcat_lt.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arn]

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "banca-digital"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${local.name_prefix}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.tomcat_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${local.name_prefix}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.tomcat_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = var.cpu_threshold_high
  alarm_description   = "CPU utilization high - scale up"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.tomcat_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
  tags          = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.name_prefix}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 180
  statistic           = "Average"
  threshold           = var.cpu_threshold_low
  alarm_description   = "CPU utilization low - scale down"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.tomcat_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
  tags          = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${local.name_prefix}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "System/Linux"
  period              = 120
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Memory utilization high"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.tomcat_asg.name
  }

  tags = local.common_tags
}

resource "aws_s3_bucket" "tomcat_logs" {
  bucket = "banca-digital-tomcat-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name = "Tomcat logs bucket"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tomcat_logs" {
  bucket = aws_s3_bucket.tomcat_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudwatch_logs" {
  bucket = aws_s3_bucket.tomcat_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchPutObject"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.tomcat_logs.id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control",
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}