locals {
  name_prefix = "banca-digital-${var.environment}"
  common_tags = {
    Environment = var.environment
    Project     = "banca-digital"
    ManagedBy   = "terraform"
    Owner       = "cloudops-team"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = local.name_prefix
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnets_cidr
  private_subnets = var.private_subnets_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags

  public_subnet_tags = {
    Type = "public"
  }

  private_subnet_tags = {
    Type = "private"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = module.vpc.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_eip" "nat_gateway" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eip-${count.index}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id     = module.vpc.public_subnets[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  count = length(var.availability_zones)

  vpc_id = module.vpc.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets_cidr)

  subnet_id      = module.vpc.private_subnets[count.index]
  route_table_id = aws_route_table.private[count.index % length(var.availability_zones)].id
}

resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB - allows HTTP/HTTPS traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "bastion_sg" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Security group for bastion host - allows SSH from office"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from office IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.office_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-bastion-sg"
  })
}

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = local.common_tags
}

resource "aws_lb_target_group" "tomcat" {
  name     = "${local.name_prefix}-tomcat-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 86400
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat.arn
  }
}

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat.arn
  }
}

resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami           = var.bastion_ami
  instance_type = var.bastion_instance_type
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-bastion"
  })
}

resource "aws_route53_zone" "private" {
  count = var.enable_private_dns ? 1 : 0

  name = "banca-digital.internal"

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  tags = local.common_tags
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    [aws_route_table.private[0].id]
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.region}.ssm"

  route_table_ids = module.vpc.private_route_table_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.region}.logs"

  route_table_ids = module.vpc.private_route_table_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-logs-endpoint"
  })
}

resource "aws_flow_log" "vpc_flow_logs" {
  log_destination      = var.flow_logs_bucket_arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = module.vpc.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-flow-logs"
  })
}