package main

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "aws_s3_bucket"  # only target actual S3 buckets
  bucket := rc.change.after.bucket
  not startswith(bucket, "company-")
  msg := sprintf("Bucket name must start with 'company-': %v", [rc.address])
}
