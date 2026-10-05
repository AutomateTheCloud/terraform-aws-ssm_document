# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A Package document whose attachment is an S3 object created in the same run, so the
# attachment's location is unknown until apply.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
resource "aws_s3_object" "package" {
  bucket  = "amzn-s3-demo-bucket"
  key     = "packages/agent.zip"
  content = "not a real package"
}

module "ssm_document" {
  source = "../../.."

  details          = { scope = "Test", purpose = "Same Run", environment = "test" }
  name             = "test-package"
  document_type    = "Package"
  document_format  = "JSON"
  document_content = jsonencode({ schemaVersion = "2.0", version = "1.0", packages = {}, files = {} })
  attachments = [
    { key = "S3FileUrl", values = ["s3://${aws_s3_object.package.bucket}/${aws_s3_object.package.id}"], name = "agent.zip" },
  ]
}

output "metadata" {
  value = module.ssm_document.metadata
}
