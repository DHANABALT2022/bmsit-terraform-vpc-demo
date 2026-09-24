terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Credentials come from "aws configure" (~/.aws/credentials), never from this file
provider "aws" {
  region = var.region

  # These tags are added to every resource automatically
  default_tags {
    tags = {
      Project   = "bmsit-fdp"
      ManagedBy = "terraform"
    }
  }
}
