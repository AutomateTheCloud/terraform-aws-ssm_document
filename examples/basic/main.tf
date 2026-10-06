# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A Command document, read from a YAML file, that prints a message on Linux EC2
# instances. Run it with Run Command or a State Manager association.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "ssm_document" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Basic SSM Document"
    environment = "Development"
  }

  name             = "example-hello-world"
  document_content = file("${path.module}/files/hello_world.yaml")
}

output "document" {
  description = "The document's name, ARN and default version"
  value = {
    name            = module.ssm_document.metadata.ssm_document.name
    arn             = module.ssm_document.metadata.ssm_document.arn
    default_version = module.ssm_document.metadata.ssm_document.default_version
  }
}
