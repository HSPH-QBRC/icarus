terraform {
  required_version = ">= 1.1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.7.0"
    }
  }

  backend "s3" {
    bucket               = "icarus-terraform"
    key                  = "terraform.tfstate"
    region               = "us-east-2"
    workspace_key_prefix = "workspace"
  }
}

locals {
  secrets_dir = "/home/centos"
  tags        = { Name : "${title(terraform.workspace)} Icarus", Project : "Icarus", Terraform : "True" }
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = local.tags
  }
}
