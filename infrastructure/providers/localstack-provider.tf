provider "aws" {
  region            = var.aws_region
  access_key        = "test"
  secret_key        = "test"
  s3_use_path_style = true

  endpoints {
    s3   = "http://localhost:4566"
    iam  = "http://localhost:4566"
    ec2  = "http://localhost:4566"
    sqs  = "http://localhost:4566"
    sns  = "http://localhost:4566"
    lambda = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    sts  = "http://localhost:4566"   
  }
}
