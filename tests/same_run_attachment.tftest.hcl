# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_resource "aws_s3_object" {
    defaults = { id = "packages/agent.zip" }
  }
}

# An attachment whose location is known only after apply still plans.
run "same_run_attachment_plans" {
  command = plan
  module { source = "./tests/fixtures/same_run_attachment" }
}

run "same_run_attachment_applies" {
  command = apply
  module { source = "./tests/fixtures/same_run_attachment" }
  assert {
    condition     = output.metadata.ssm_document.attachments_source[0].values == tolist(["s3://amzn-s3-demo-bucket/packages/agent.zip"])
    error_message = "The attachment location did not reach the document."
  }
}
