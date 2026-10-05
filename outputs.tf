# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

output "metadata" {
  description = <<-EOT
    Everything the module created, in one object, so that other configurations need only one reference:

    - `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
    - `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
    - `ssm_document` - The document:

      - `name` - The name to run it by, such as in an `aws_ssm_association`. `id` is the same value.
      - `arn` - Its Amazon Resource Name (ARN), for IAM policies such as one allowing `ssm:SendCommand` with this document. For an `Automation` document it is the `automation-definition` ARN, which `ssm:StartAutomationExecution` uses.
      - `default_version` - The version that runs when no version is given. The module makes each new version the default.
      - `latest_version` and `document_version` - The newest version number, and the version Terraform last read.
      - `version_name` - The name of the current version, if `version_name` was set.
      - `status` - `Active` once AWS has accepted the document.
      - `parameter` - The parameters the content declares, each with `name`, `type`, `description` and `default_value`.
      - `platform_types` - The operating systems the content can run on, such as `Linux` and `Windows`.
      - `description` and `schema_version` - Read from the content.
      - `content`, `document_format`, `document_type`, `target_type` and `attachments_source` - As set by the inputs.
      - `hash` and `hash_type` - A SHA-256 hash of the content.
      - `owner` - The AWS account ID that owns the document.
      - `created_date`, `region`, `tags` and `tags_all`.
  EOT
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    # One entry per resource.
    ssm_document = local.output_resources.ssm_document
  }
}

locals {
  # Each resource's attributes are listed one by one. Referencing a whole resource
  # would also reference any attribute the provider deprecates later, and every
  # caller's plan would print deprecation warnings.
  # permissions is left out: the module shares the document with no one, and the
  # provider saves it as null and reads it back as {}, so every caller's first plan
  # after a create would show the output changing.
  output_resources = {
    ssm_document = {
      arn                = aws_ssm_document.this.arn
      attachments_source = aws_ssm_document.this.attachments_source
      content            = aws_ssm_document.this.content
      created_date       = aws_ssm_document.this.created_date
      default_version    = aws_ssm_document.this.default_version
      description        = aws_ssm_document.this.description
      document_format    = aws_ssm_document.this.document_format
      document_type      = aws_ssm_document.this.document_type
      document_version   = aws_ssm_document.this.document_version
      hash               = aws_ssm_document.this.hash
      hash_type          = aws_ssm_document.this.hash_type
      id                 = aws_ssm_document.this.id
      latest_version     = aws_ssm_document.this.latest_version
      name               = aws_ssm_document.this.name
      owner              = aws_ssm_document.this.owner
      parameter          = aws_ssm_document.this.parameter
      platform_types     = aws_ssm_document.this.platform_types
      region             = aws_ssm_document.this.region
      schema_version     = aws_ssm_document.this.schema_version
      status             = aws_ssm_document.this.status
      tags               = aws_ssm_document.this.tags
      tags_all           = aws_ssm_document.this.tags_all
      target_type        = aws_ssm_document.this.target_type
      version_name       = aws_ssm_document.this.version_name
    }

  }
}
