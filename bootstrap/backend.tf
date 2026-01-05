# Initial setup of S3 bucket to store tfstate file

variable "region" {
  type        = string
  default     = "ap-southeast-2"
  description = "AWS region"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14"
    }
  }
  required_version = ">= 1.10.0"
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "umccr-org:Creator": "terraform"
      "umccr-org:Product": "k8tre"
      "umccr-org:Source": "https://github.com/umccr/k8tre-aws"
    }
  }
}

resource "aws_s3_bucket" "bucket" {
  # Generate a random bucket name, e.g. `openssl rand -hex 8`
  bucket = "tfstate-k8tre-dev-ff5e2f01a9f253fc"
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "ssl_only" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.ssl_only.json
}

data "aws_iam_policy_document" "ssl_only" {
  statement {
    principals {
      identifiers = ["*"]
      type = "*"
    }
    actions = ["s3:*"]
    effect = "Deny"
    condition {
      test     = "Bool"
      values = ["false"]
      variable = "aws:SecureTransport"
    }
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}
