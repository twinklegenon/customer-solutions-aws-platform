terraform {
  backend "s3" {
    bucket = "customer-solutions-platform-state-file"
    key    = "customer-solutions-platform-state-file/prod/terraform.tfstate"
    region = "ap-southeast-1"

    # Lock the state with a lock file in the bucket, and encrypt it at rest.
    use_lockfile = true
    encrypt      = true
  }
}
