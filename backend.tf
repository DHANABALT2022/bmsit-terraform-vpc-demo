terraform {
  backend "s3" {
    bucket       = "bmsit2059847"
    key          = "vpc-demo/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}