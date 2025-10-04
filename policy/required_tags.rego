package main

required_tags = {"Owner", "Environment"}

deny[msg] {
  resource := input.resource_changes[_].change.after
  resource.tags
  tag := required_tags[_]
  not resource.tags[tag]
  msg = sprintf("Resource %v is missing required tag: %v", [resource, tag])
}
