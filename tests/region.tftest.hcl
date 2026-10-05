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
  details          = { scope = "Test", purpose = "Region", environment = "test" }
  name             = "test-document"
  document_content = "schemaVersion: '2.2'\ndescription: Test\nmainSteps: []\n"
}

# The module uses the default aws provider: no providers block is needed.
run "provider_region_by_default" {
  command = plan
  assert {
    condition     = output.metadata.aws.region.name == "us-east-1"
    error_message = "Expected the provider's Region."
  }
}

run "region_reaches_every_resource" {
  command = apply
  variables { region = "us-west-2" }
  assert {
    condition = alltrue([
      aws_ssm_document.this.region == "us-west-2",
      output.metadata.ssm_document.region == "us-west-2",
      output.metadata.aws.region.name == "us-west-2",
      output.metadata.aws.region.abbr == "usw2",
    ])
    error_message = "region was not passed through to every resource."
  }
}

# Regression: the old hard-coded Region table failed the plan in any Region missing
# from it, such as ca-west-1.
run "region_abbreviation_not_in_old_table" {
  command = plan
  variables { region = "ca-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "caw1"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_new_region" {
  command = plan
  variables { region = "ap-southeast-7" }
  assert {
    condition     = output.metadata.aws.region.abbr == "apse7"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_override" {
  command = plan
  variables { region = "us-gov-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "ugw1"
    error_message = "Unexpected abbreviation."
  }
}
