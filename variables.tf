# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "attachments" {
  description = <<-EOT
    Files to attach to the document, such as the software in a `Package` document or a script that an `Automation` document runs. AWS copies each file when the document version is created, so later changes to the source do not reach the document. An empty list, the default, attaches nothing. At most 20.

    Each attachment takes:

    - `key` - (Required) Where the file comes from: `S3FileUrl` (one file in Amazon S3), `SourceUrl` (an S3 prefix) or `AttachmentReference` (a file attached to another document version in this account).
    - `values` - (Required) A list of exactly one location, such as `["s3://amzn-s3-demo-bucket/my-prefix/my-file.zip"]` for `S3FileUrl`, or `["OtherDocument/3/my-file.zip"]` for `AttachmentReference`.
    - `name` - (Optional) The file name the document uses for it: 3 to 128 letters, numbers, `_`, `-` and `.`.
  EOT
  type = list(object({
    key    = string
    values = list(string)
    name   = optional(string)
  }))
  default  = []
  nullable = false

  validation {
    condition     = length(var.attachments) <= 20
    error_message = "A document can have at most 20 attachments."
  }

  validation {
    condition     = alltrue([for a in var.attachments : contains(["S3FileUrl", "SourceUrl", "AttachmentReference"], a.key)])
    error_message = "Each attachment key must be S3FileUrl, SourceUrl or AttachmentReference."
  }

  validation {
    condition     = alltrue([for a in var.attachments : length(a.values) == 1 && alltrue([for v in a.values : length(v) >= 1 && length(v) <= 1024])])
    error_message = "Each attachment takes exactly one value, of 1 to 1024 characters."
  }

  validation {
    condition     = alltrue([for a in var.attachments : a.name == null || can(regex("^[a-zA-Z0-9_.-]{3,128}$", a.name))])
    error_message = "Each attachment name must be 3 to 128 letters, numbers, underscores, hyphens or periods."
  }
}

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-ssm_document#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web Site`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "document_content" {
  description = <<-EOT
    The document itself, in the format set by `document_format`. Read it from a file with `file("$${path.module}/files/my-document.yaml")`, or build JSON with `jsonencode()`. Changing it creates a new version of the document and makes that version the default; the document keeps its name and earlier versions.

    The content must match `document_type`: a `Command` document needs `schemaVersion` `2.2` and `mainSteps`, for example. AWS checks it when the document is created or updated, not at plan time. See [SSM document schema features and examples](https://docs.aws.amazon.com/systems-manager/latest/userguide/document-schemas-features.html).
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.document_content) != ""
    error_message = "Document content not specified."
  }
}

variable "document_format" {
  description = <<-EOT
    The format of `document_content`: `YAML` (the default), `JSON`, or `TEXT`. `TEXT` is only for document types that are not JSON or YAML, such as some `ApplicationConfiguration` documents. Changing it creates a new version of the document.
  EOT
  type        = string
  default     = "YAML"
  nullable    = false
}

variable "document_type" {
  description = <<-EOT
    The type of document, which decides what can use it. The default is `Command`, for documents that Run Command, State Manager and Maintenance Windows run on managed nodes. Others include `Automation` (runbooks), `Session` (Session Manager preferences and session types), `Package` (software for Distributor, with `attachments`), `Policy` and `ChangeCalendar`. The AWS provider lists every accepted type and rejects any other at plan time.

    Changing it deletes the document and creates a new one with the same name.
  EOT
  type        = string
  default     = "Command"
  nullable    = false
}

variable "name" {
  description = <<-EOT
    The name of the document, which is how Run Command, State Manager, Automation and other services refer to it: 3 to 128 letters, numbers, `_`, `-` and `.`. It must be unique in the account and Region. AWS reserves some prefixes for its own documents, in any combination of upper and lower case: names cannot start with `amazon` or `amzn`, or with `aws-`, `awsec2-`, `awssupport-` or `awsconfigremediation-`. The module checks those at plan time. AWS also rejects some other names that start with `AWS` and a hyphen, such as `AWSResilienceHub-`, but only when the document is created.

    Changing it deletes the document and creates a new one, so anything that refers to the old name, such as a State Manager association, must change too.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = !can(regex("^(?i)(amazon|amzn|(aws|awsec2|awssupport|awsconfigremediation)-)", var.name))
    error_message = "The name cannot start with amazon, amzn, aws-, awsec2-, awssupport- or awsconfigremediation-, in any case: AWS reserves those prefixes."
  }
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the document in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module. A document can be used only in its own Region. Changing it deletes the document and creates a new one in the new Region.
  EOT
  type        = string
  default     = null
}

variable "target_type" {
  description = <<-EOT
    The kinds of resources the document can run on, as a CloudFormation resource type after a `/`. The default, `/AWS::EC2::Instance`, allows EC2 instances. `/` allows every type. `null` sets no target type; according to the [`CreateDocument` API reference](https://docs.aws.amazon.com/systems-manager/latest/APIReference/API_CreateDocument.html), the document then cannot run on any resource. The AWS provider rejects a value that does not start with `/` at plan time.
  EOT
  type        = string
  default     = "/AWS::EC2::Instance"
}

variable "version_name" {
  description = <<-EOT
    A name for this version of the document, such as `Release12.1`: 3 to 128 letters, numbers, `_`, `-` and `.`. (AWS accepts shorter names, but the AWS provider does not.) The default, `null`, sets none. Each version name must be unique within the document, so change it together with `document_content`; AWS rejects an update that reuses a version name.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.version_name == null || can(regex("^[a-zA-Z0-9_.-]{3,128}$", var.version_name))
    error_message = "The version name must be 3 to 128 letters, numbers, underscores, hyphens or periods."
  }
}
