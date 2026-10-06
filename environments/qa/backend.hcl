bucket         = "terraform-state-banca-digital-qa"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock-qa"
acl            = "bucket-owner-full-control"
