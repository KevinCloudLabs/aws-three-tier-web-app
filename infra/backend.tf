terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }

  backend "s3" {
    bucket         = "kevin-terraform-state-three-tier"
    key            = "three-tier/terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "terraform-state-lock-three-tier"
    encrypt        = true
  }
}
