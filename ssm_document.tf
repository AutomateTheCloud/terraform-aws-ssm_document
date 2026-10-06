# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# AWS cannot change a document's type, and the AWS provider plans a type change as an
# update that does nothing: the apply succeeds, the type stays, and every later plan
# shows the change again. Replacing the document when the type changes makes the
# change real.
resource "terraform_data" "document_type" {
  input = var.document_type
}

resource "aws_ssm_document" "this" {
  region = var.region

  name            = var.name
  document_type   = var.document_type
  document_format = var.document_format
  target_type     = var.target_type
  version_name    = var.version_name
  content         = var.document_content

  dynamic "attachments_source" {
    for_each = var.attachments
    content {
      key    = attachments_source.value.key
      values = attachments_source.value.values
      name   = attachments_source.value.name
    }
  }

  tags = local.tags

  lifecycle {
    replace_triggered_by = [terraform_data.document_type]
  }
}
