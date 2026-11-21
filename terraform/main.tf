terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  backend "s3" {
    bucket       = "athlete-pipeline-tfstate-710412005872"
    key          = "athlete-pipeline/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = {
      Project   = "athlete-data-pipeline"
      ManagedBy = "terraform"
    }
  }
}

# Bucket where athlete test results (CSV) will land
resource "aws_s3_bucket" "raw" {
  bucket = "athlete-pipeline-raw-710412005872"
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
