package main

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "aws_s3_bucket"           # only evaluate S3 buckets
  acl := rc.change.after.acl
  acl == "public-read"                 # or any non-private ACL you want to block
  msg := sprintf("S3 bucket %v has a public ACL: %v", [rc.address, acl])
}
