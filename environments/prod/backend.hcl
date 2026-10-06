bucket         = "terraform-state-banca-digital-prod"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock-prod"
acl            = "bucket-owner-full-control"
