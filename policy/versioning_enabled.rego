package main

deny[msg] {
  input.resource_changes[_].type == "aws_s3_bucket_versioning"
  input.resource_changes[_].change.after.versioning_configuration.status != "Enabled"
  msg = sprintf("S3 bucket versioning must be enabled for %v", [input.resource_changes[_].address])
}
