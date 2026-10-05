# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# An Automation runbook in us-west-2, set through the module's region input while the
# provider stays in us-east-1. The runbook runs a Python script that is attached to
# the document from a private S3 bucket created in the same run. The content is built
# with jsonencode, and each version has a name.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  region = "us-west-2"

  details = {
    scope            = "Example"
    purpose          = "Complete SSM Document"
    purpose_abbr     = "ssm_document"
    environment      = "Development"
    environment_abbr = "dev"
    additional_tags  = { CostCenter = "1234" }
  }
}

# Bucket names are global, so add a random suffix.
resource "random_id" "suffix" {
  byte_length = 4
}

# A private, encrypted bucket for the script. AWS copies the file into the document
# version when it is created, so the bucket is needed only to create a new version.
# Versioning keeps each earlier script; old versions are deleted after 30 days.
module "scripts" {
  source  = "AutomateTheCloud/s3_bucket/aws"
  version = "~> 1.0"

  region        = local.region
  details       = local.details
  name          = "example-ssm-document-${random_id.suffix.hex}"
  versioning    = { enabled = true }
  force_destroy = true

  lifecycle_rules = [
    {
      rule_name                              = "Clean up old versions"
      enabled                                = true
      abort_incomplete_multipart_upload_days = 7
      noncurrent_version_expiration          = { days = 30 }
      expiration                             = { expired_object_delete_marker = true }
    }
  ]
}

resource "aws_s3_object" "greet" {
  region = local.region
  bucket = module.scripts.metadata.s3_bucket.bucket
  key    = "scripts/greet.py"
  source = "${path.module}/files/greet.py"
  etag   = filemd5("${path.module}/files/greet.py")
}

module "ssm_document" {
  source = "../../"

  region  = local.region
  details = local.details

  name            = "example-greeting-runbook"
  document_type   = "Automation"
  document_format = "JSON"
  target_type     = "/"

  # Name each version, and change the name whenever the content or the script
  # changes: AWS rejects a new version with a name already used.
  version_name = "1.0.0"

  attachments = [
    {
      key    = "S3FileUrl"
      values = ["s3://${aws_s3_object.greet.bucket}/${aws_s3_object.greet.key}"]
      name   = "greet.py"
    },
  ]

  document_content = jsonencode({
    schemaVersion = "0.3"
    description   = "Returns a greeting from an attached Python script."
    parameters = {
      Message = {
        type        = "String"
        description = "Who to greet."
        default     = "world"
      }
    }
    mainSteps = [
      {
        name   = "Greet"
        action = "aws:executeScript"
        inputs = {
          Runtime      = "python3.11"
          Handler      = "greet.handler"
          Attachment   = "greet.py"
          InputPayload = { message = "{{ Message }}" }
        }
        outputs = [
          { Name = "Greeting", Selector = "$.Payload.greeting", Type = "String" },
        ]
      },
    ]
    outputs = ["Greet.Greeting"]

    # Each attached file, with its SHA-256 hash. AWS checks the attachment against it.
    files = {
      "greet.py" = { checksums = { sha256 = filesha256("${path.module}/files/greet.py") } }
    }
  })
}

output "document" {
  description = "The runbook's name, ARN, Region and default version"
  value = {
    name            = module.ssm_document.metadata.ssm_document.name
    arn             = module.ssm_document.metadata.ssm_document.arn
    region          = module.ssm_document.metadata.aws.region.name
    default_version = module.ssm_document.metadata.ssm_document.default_version
  }
}
