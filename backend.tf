# Backend remoto S3 con configuración parcial: un bloque backend no admite
# variables, así que bucket, key, región y tabla de bloqueo se inyectan por
# ambiente en el init:
#   terraform init -backend-config=environments/<env>/backend.hcl
terraform {
  backend "s3" {}
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-${var.project_name}-${var.environment}"

  lifecycle_rule {
    enabled = true

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Terraform State Storage"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Terraform State Lock"
    ManagedBy   = "Terraform"
  }
}

resource "aws_dynamodb_table_item" "terraform_lock_initial" {
  table_name = aws_dynamodb_table.terraform_lock.name
  hash_key   = aws_dynamodb_table.terraform_lock.hash_key

  item = jsonencode({
    LockID = {
      S = "infrastructure/terraform.tfstate"
    }
    Info = {
      S = "Initial lock entry for ${var.environment} environment"
    }
    Operation = {
      S = "Init"
    }
  })
}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for terraform state encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "terraform-state-key-policy"
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
        Sid    = "Allow S3 to use this key for bucket encryption"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Terraform State Encryption"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state-${var.environment}"
  target_key_id = aws_kms_key.terraform_state.key_id
}