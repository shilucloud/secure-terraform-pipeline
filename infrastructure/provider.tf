locals {
  localstack_enabled = var.localstack_enabled
}

provider "aws" {
  region = var.aws_region

  dynamic "endpoints" {
    for_each = local.localstack_enabled ? [1] : []
    content {
      s3  = "http://localhost:4566"
      sts = "http://localhost:4566"
    }
  }

  access_key                  = local.localstack_enabled ? "test" : null
  secret_key                  = local.localstack_enabled ? "test" : null
  skip_credentials_validation = local.localstack_enabled
  skip_requesting_account_id  = local.localstack_enabled
}
