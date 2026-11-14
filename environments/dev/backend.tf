terraform {
  backend "s3" {
    bucket = "customer-solutions-platform-state-file"
    key    = "customer-solutions-platform-state-file/dev/terraform.tfstate"
    region = "ap-southeast-1"
  }
}
