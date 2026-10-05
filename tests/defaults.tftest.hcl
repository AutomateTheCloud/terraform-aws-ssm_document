# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_resource "aws_ssm_document" {
    defaults = {
      arn             = "arn:aws:ssm:us-east-1:111111111111:document/test-document"
      default_version = "1"
      latest_version  = "1"
      status          = "Active"
      owner           = "111111111111"
    }
  }
}

variables {
  details          = { scope = "Test", purpose = "Defaults", environment = "test" }
  name             = "test-document"
  document_content = "schemaVersion: '2.2'\ndescription: Test\nmainSteps: []\n"
}

# With only the required inputs: a YAML Command document for EC2 instances, with no
# version name, no attachments, and shared with no one.
run "defaults_plan" {
  command = plan

  assert {
    condition = alltrue([
      aws_ssm_document.this.name == "test-document",
      aws_ssm_document.this.document_type == "Command",
      aws_ssm_document.this.document_format == "YAML",
      aws_ssm_document.this.target_type == "/AWS::EC2::Instance",
      aws_ssm_document.this.version_name == null,
      aws_ssm_document.this.permissions == null,
      length(aws_ssm_document.this.attachments_source) == 0,
    ])
    error_message = "Unexpected configuration with only the required inputs."
  }
}

run "defaults_apply" {
  command = apply

  assert {
    condition = alltrue([
      output.metadata.ssm_document.name == "test-document",
      output.metadata.ssm_document.arn == "arn:aws:ssm:us-east-1:111111111111:document/test-document",
      output.metadata.ssm_document.status == "Active",
      output.metadata.ssm_document.content == "schemaVersion: '2.2'\ndescription: Test\nmainSteps: []\n",
      output.metadata.aws.region.name == "us-east-1",
      output.metadata.aws.region.abbr == "use1",
      output.metadata.aws.account.id == "111111111111",
      output.metadata.details.purpose.abbr == "defaults",
    ])
    error_message = "Unexpected metadata output."
  }
}

# Regression: the AWS provider plans a document_type change as an in-place update that
# does nothing in AWS. The module replaces the document instead, through
# terraform_data.document_type, which holds the type.
run "document_type_replaces" {
  command = apply
  variables { document_type = "Automation" }
  assert {
    condition     = terraform_data.document_type.output == "Automation"
    error_message = "terraform_data.document_type must follow document_type."
  }
}

run "tags" {
  command = plan
  variables {
    details = { scope = "Test Scope", purpose = "Defaults", environment = "test", additional_tags = { CostCenter = "1234" } }
  }
  assert {
    condition = aws_ssm_document.this.tags == tomap({
      Scope       = "Test Scope"
      Purpose     = "Defaults"
      Environment = "test"
      CostCenter  = "1234"
    })
    error_message = "Unexpected tags."
  }
  assert {
    condition     = output.metadata.details.scope.abbr == "test_scope" && output.metadata.details.scope.machine == "testscope"
    error_message = "Unexpected abbreviations."
  }
}

# An empty abbreviation override is ignored, not used as an empty name part.
run "empty_abbr_ignored" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Defaults", environment = "test", environment_abbr = "" }
  }
  assert {
    condition     = output.metadata.details.environment.abbr == "test"
    error_message = "An empty environment_abbr should fall back to the generated abbreviation."
  }
}

run "every_option" {
  command = plan
  variables {
    document_type   = "Package"
    document_format = "JSON"
    target_type     = "/"
    version_name    = "Release1.0"
    attachments = [
      { key = "S3FileUrl", values = ["s3://amzn-s3-demo-bucket/agent.zip"], name = "agent.zip" },
      { key = "AttachmentReference", values = ["OtherDocument/3/other.zip"] },
    ]
  }
  assert {
    condition = alltrue([
      aws_ssm_document.this.document_type == "Package",
      aws_ssm_document.this.document_format == "JSON",
      aws_ssm_document.this.target_type == "/",
      aws_ssm_document.this.version_name == "Release1.0",
      length(aws_ssm_document.this.attachments_source) == 2,
      aws_ssm_document.this.attachments_source[0].key == "S3FileUrl",
      aws_ssm_document.this.attachments_source[0].values == tolist(["s3://amzn-s3-demo-bucket/agent.zip"]),
      aws_ssm_document.this.attachments_source[0].name == "agent.zip",
      aws_ssm_document.this.attachments_source[1].key == "AttachmentReference",
      aws_ssm_document.this.attachments_source[1].name == null,
    ])
    error_message = "Options were not passed through."
  }
}

# target_type = null sets no target type.
run "target_type_null" {
  command = plan
  variables { target_type = null }
  assert {
    condition     = aws_ssm_document.this.target_type == null
    error_message = "target_type = null should set no target type."
  }
}
