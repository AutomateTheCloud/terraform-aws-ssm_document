# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

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
  details          = { scope = "Test", purpose = "Validation", environment = "test" }
  name             = "test-document"
  document_content = "schemaVersion: '2.2'\ndescription: Test\nmainSteps: []\n"
}

run "details_scope_empty" {
  command = plan
  variables { details = { scope = " ", purpose = "Validation", environment = "test" } }
  expect_failures = [var.details]
}

run "details_purpose_empty" {
  command = plan
  variables { details = { scope = "Test", purpose = "", environment = "test" } }
  expect_failures = [var.details]
}

run "details_environment_empty" {
  command = plan
  variables { details = { scope = "Test", purpose = "Validation", environment = "" } }
  expect_failures = [var.details]
}

# Regression: the old module defaulted document_content to "", which planned and
# failed only at apply.
run "content_empty" {
  command = plan
  variables { document_content = "  \n" }
  expect_failures = [var.document_content]
}

run "name_reserved_prefix_aws" {
  command = plan
  variables { name = "AWS-RunMyScript" }
  expect_failures = [var.name]
}

run "name_reserved_prefix_amazon" {
  command = plan
  variables { name = "amazonTest" }
  expect_failures = [var.name]
}

run "name_reserved_prefix_amzn" {
  command = plan
  variables { name = "aMzNtest" }
  expect_failures = [var.name]
}

run "name_reserved_prefix_awsec2" {
  command = plan
  variables { name = "AwsEc2-test" }
  expect_failures = [var.name]
}

run "name_reserved_prefix_awssupport" {
  command = plan
  variables { name = "awssupport-test" }
  expect_failures = [var.name]
}

run "name_reserved_prefix_awsconfigremediation" {
  command = plan
  variables { name = "AWSConfigRemediation-test" }
  expect_failures = [var.name]
}

# AWS accepts these (checked with the CLI): aws without a hyphen, and a reserved
# word later in the name.
run "name_aws_without_hyphen" {
  command = plan
  variables { name = "AWSRunbook" }
}

run "name_aws_underscore" {
  command = plan
  variables { name = "aws_runbook" }
}

run "name_reserved_word_not_prefix" {
  command = plan
  variables { name = "my-aws-document" }
}

run "version_name_invalid" {
  command = plan
  variables { version_name = "release 1" }
  expect_failures = [var.version_name]
}

# AWS accepts 1 and 2 characters, but the AWS provider requires 3.
run "version_name_too_short" {
  command = plan
  variables { version_name = "v1" }
  expect_failures = [var.version_name]
}

run "version_name_too_long" {
  command = plan
  variables { version_name = join("", [for i in range(129) : "a"]) }
  expect_failures = [var.version_name]
}

run "attachment_key_invalid" {
  command = plan
  variables { attachments = [{ key = "S3Url", values = ["s3://amzn-s3-demo-bucket/a.zip"] }] }
  expect_failures = [var.attachments]
}

run "attachment_two_values" {
  command = plan
  variables { attachments = [{ key = "S3FileUrl", values = ["s3://amzn-s3-demo-bucket/a.zip", "s3://amzn-s3-demo-bucket/b.zip"] }] }
  expect_failures = [var.attachments]
}

run "attachment_no_values" {
  command = plan
  variables { attachments = [{ key = "S3FileUrl", values = [] }] }
  expect_failures = [var.attachments]
}

run "attachment_name_invalid" {
  command = plan
  variables { attachments = [{ key = "S3FileUrl", values = ["s3://amzn-s3-demo-bucket/a.zip"], name = "a b.zip" }] }
  expect_failures = [var.attachments]
}

run "attachments_too_many" {
  command = plan
  variables { attachments = [for i in range(21) : { key = "S3FileUrl", values = ["s3://amzn-s3-demo-bucket/${i}.zip"] }] }
  expect_failures = [var.attachments]
}
