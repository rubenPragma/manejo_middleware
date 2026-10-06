bucket         = "terraform-state-banca-digital-dev"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock-dev"
acl            = "bucket-owner-full-control"
