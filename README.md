# Terraform module for AWS Systems Manager documents

Creates an AWS Systems Manager (SSM) document: a named set of steps that Systems Manager runs for you. A `Command` document runs commands on your instances through Run Command, State Manager or Maintenance Windows. An `Automation` document, also called a runbook, runs AWS API calls and scripts. Other types configure Session Manager, Distributor packages and Change Calendar.

The module creates the document, keeps every version of it as its content changes, and tags it. It does not run the document or share it with other accounts.

## What it configures

| Setting | Default | Input |
|---|---|---|
| Document type | `Command` | `document_type` |
| Content format | YAML | `document_format` |
| Resources it can run on | EC2 instances (`/AWS::EC2::Instance`) | `target_type` |
| Version name | None | `version_name` |
| Attached files | None | `attachments` |
| Sharing with other accounts | None: the document is private to your account | Not in the module |
| Region | The AWS provider's Region | `region` |
| Tags | `Scope`, `Purpose`, `Environment`, and any `additional_tags` | `details` |

## Usage

```hcl
module "ssm_document" {
  source  = "AutomateTheCloud/ssm_document/aws"
  version = "~> 1.0"

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Web Site"
    environment = "Production"
  }

  name             = "web-site-restart-nginx"
  document_content = file("${path.module}/files/restart-nginx.yaml")
}
```

`details`, `name` and `document_content` are the only required inputs. The content above is a `Command` document in YAML, such as:

```yaml
schemaVersion: "2.2"
description: Restarts nginx
mainSteps:
  - action: aws:runShellScript
    name: restart
    inputs:
      runCommand:
        - systemctl restart nginx
```

Run it by name, for example with a State Manager association:

```hcl
resource "aws_ssm_association" "restart_nginx" {
  name = module.ssm_document.metadata.ssm_document.name

  targets {
    key    = "tag:Role"
    values = ["web"]
  }
}
```

The module uses your default `aws` provider and creates the document in that provider's Region. A document can be used only in its own Region. To create one somewhere else without configuring another provider, set `region`:

```hcl
module "ssm_document_us_west_2" {
  source  = "AutomateTheCloud/ssm_document/aws"
  version = "~> 1.0"

  region           = "us-west-2"
  details          = { scope = "Automate the Cloud", purpose = "Web Site", environment = "Production" }
  name             = "web-site-restart-nginx"
  document_content = file("${path.module}/files/restart-nginx.yaml")
}
```

To use a provider configured for another account, pass it explicitly with `providers = { aws = aws.other_account }`.

## The `details` input

Most modules ask only for what the resource itself needs. This one also requires `details`: three names that say what the document belongs to, what it is for, and which environment it is in. Every Automate the Cloud module takes the same input, and requiring it is deliberate.

```hcl
details = {
  scope       = "Automate the Cloud" # what it belongs to: an organization, team or project
  purpose     = "Web Site"           # what it is for
  environment = "Production"         # which environment
}
```

**Every resource can be traced.** The three names become the `Scope`, `Purpose` and `Environment` tags on every resource the module creates. Months later, anyone looking at an SSM document in the AWS console, or at a line on the bill, can see who it belongs to and why it exists. With cost allocation tags turned on in AWS Billing, the same tags split your bill by project and environment. Because the input is required and checked, no resource can be created without them.

**One definition for a whole stack.** Write `details` once and pass the same value to every module, so the document, the instances it runs on, their VPC and everything else are tagged alike. Tags you want everywhere, such as a cost center or the Terraform workspace, go in `additional_tags`:

```hcl
locals {
  details = {
    scope           = "Automate the Cloud"
    purpose         = "Web Site"
    environment     = "Production"
    additional_tags = { CostCenter = "1234", IaC = "true" }
  }
}

module "restart_nginx" {
  source  = "AutomateTheCloud/ssm_document/aws"
  version = "~> 1.0"

  details          = local.details
  name             = "web-site-restart-nginx"
  document_content = file("${path.module}/files/restart-nginx.yaml")
}
```

**Consistent names.** The module turns each name into two short forms other resources can be named with: `abbr`, lowercase with words joined by underscores (`Web Site` becomes `web_site`), and `machine`, lowercase letters and numbers only (`website`), for resources that allow no underscores. It also works out a short form of the Region, such as `use1` for `us-east-1`. Every module derives these the same way, so names stay consistent across a stack. To choose your own short forms, set `scope_abbr`, `purpose_abbr` or `environment_abbr`, for example `environment_abbr = "prd"`.

**One output to reach everything.** All of it comes back in the `metadata` output, along with everything the module created, so a configuration needs only one reference: `module.restart_nginx.metadata.ssm_document.name` for the document's name, or `module.restart_nginx.metadata.aws.region.abbr` for the Region's short form.

## Examples

Each example is a complete configuration you can run with `terraform init` and `terraform apply`.

- [Basic SSM document](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/tree/main/examples/basic): a `Command` document, read from a YAML file, that prints a message on Linux instances.
- [Complete](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/tree/main/examples/complete): an `Automation` runbook in another Region through `region`, built with `jsonencode`, with a version name and a Python script attached from a private S3 bucket.

## Things to know

### Versions

Every change to `document_content` or `target_type` creates a new version of the document, which becomes the default version: the one that runs when no version is given. Earlier versions are kept; `aws ssm list-document-versions` lists them. Destroying the module deletes the document with all its versions.

If you set `version_name`, change it in the same apply as either of those inputs. AWS rejects a new version that reuses a name (`DuplicateDocumentVersionName`), and the module cannot check that at plan time. Changing `version_name` on its own does nothing in AWS, and every plan shows the change again until the content changes too.

After an apply that changes only `target_type`, the next plan shows the version numbers in `metadata` changing, with no change to the document. The AWS provider saves the old numbers after that update. Applying that plan, or `terraform apply -refresh-only`, records the new ones.

### Changes that replace the document

Changing `name`, `document_type` or `region` deletes the document and creates a new one, with only one version. The old document is deleted first, so anything that runs it by name fails until the new one exists. If AWS rejects the new document, for example because the content does not suit the new type, the old one is already gone.

The AWS provider plans a `document_type` change as an update that does nothing in AWS. The module replaces the document instead, through a `terraform_data` resource that holds the type.

### Document names

Names are 3 to 128 letters, numbers, `_`, `-` and `.`, unique in the account and Region. AWS reserves some prefixes for its own documents, in any mix of upper and lower case: `amazon`, `amzn`, `aws-`, `awsec2-`, `awssupport-` and `awsconfigremediation-`. The module rejects those at plan time. AWS rejects some other names that start with `AWS` and a hyphen too, such as `AWSResilienceHub-`, but only when the document is created. Names such as `AWSRunbook` or `aws_runbook`, with no hyphen after `aws`, are accepted.

### Attachments

A `Package` document needs at least one attachment: AWS rejects one without (`AttachmentsSource not provided`). An `Automation` step that runs an attached script (`aws:executeScript` with `Attachment`) needs a `files` section in the content with each file's SHA-256 hash, as the [complete example](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/tree/main/examples/complete) shows.

AWS copies each attached file into the document version when the version is created. Deleting or changing the file in S3 afterward does not change the document. To publish a new script, change the file and `version_name` together, so a new version is created with the new copy.

### Sharing

The module shares the document with no one. Sharing an SSM document with other accounts, or with everyone, is not an input. If you need to share one, use the `permissions` argument of the [`aws_ssm_document`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) resource directly, outside this module.

## Contributing

Contributions are welcome, after review. Read [CONTRIBUTING.md](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/blob/main/CONTRIBUTING.md) before opening a pull request, and report security problems as described in [SECURITY.md](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/blob/main/SECURITY.md).

## Testing

The tests in `tests/` run offline against mocked AWS providers, so they need no AWS account:

```shell
terraform init
terraform test
```

## Reference

The sections below are generated from the code by [terraform-docs](https://terraform-docs.io). To update them, run `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (>= 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_details"></a> [details](#input_details)

Description: Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-ssm_document#the-details-input) explains why it is required.

- `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
- `purpose` - (Required) What the resource is for: `Web Site`.
- `environment` - (Required) The environment: `Production`.
- `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
- `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.

Type:

```hcl
object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
```

#### <a name="input_document_content"></a> [document_content](#input_document_content)

Description: The document itself, in the format set by `document_format`. Read it from a file with `file("${path.module}/files/my-document.yaml")`, or build JSON with `jsonencode()`. Changing it creates a new version of the document and makes that version the default; the document keeps its name and earlier versions.

The content must match `document_type`: a `Command` document needs `schemaVersion` `2.2` and `mainSteps`, for example. AWS checks it when the document is created or updated, not at plan time. See [SSM document schema features and examples](https://docs.aws.amazon.com/systems-manager/latest/userguide/document-schemas-features.html).

Type: `string`

#### <a name="input_name"></a> [name](#input_name)

Description: The name of the document, which is how Run Command, State Manager, Automation and other services refer to it: 3 to 128 letters, numbers, `_`, `-` and `.`. It must be unique in the account and Region. AWS reserves some prefixes for its own documents, in any combination of upper and lower case: names cannot start with `amazon` or `amzn`, or with `aws-`, `awsec2-`, `awssupport-` or `awsconfigremediation-`. The module checks those at plan time. AWS also rejects some other names that start with `AWS` and a hyphen, such as `AWSResilienceHub-`, but only when the document is created.

Changing it deletes the document and creates a new one, so anything that refers to the old name, such as a State Manager association, must change too.

Type: `string`

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_attachments"></a> [attachments](#input_attachments)

Description: Files to attach to the document, such as the software in a `Package` document or a script that an `Automation` document runs. AWS copies each file when the document version is created, so later changes to the source do not reach the document. An empty list, the default, attaches nothing. At most 20.

Each attachment takes:

- `key` - (Required) Where the file comes from: `S3FileUrl` (one file in Amazon S3), `SourceUrl` (an S3 prefix) or `AttachmentReference` (a file attached to another document version in this account).
- `values` - (Required) A list of exactly one location, such as `["s3://amzn-s3-demo-bucket/my-prefix/my-file.zip"]` for `S3FileUrl`, or `["OtherDocument/3/my-file.zip"]` for `AttachmentReference`.
- `name` - (Optional) The file name the document uses for it: 3 to 128 letters, numbers, `_`, `-` and `.`.

Type:

```hcl
list(object({
    key    = string
    values = list(string)
    name   = optional(string)
  }))
```

Default: `[]`

#### <a name="input_document_format"></a> [document_format](#input_document_format)

Description: The format of `document_content`: `YAML` (the default), `JSON`, or `TEXT`. `TEXT` is only for document types that are not JSON or YAML, such as some `ApplicationConfiguration` documents. Changing it creates a new version of the document.

Type: `string`

Default: `"YAML"`

#### <a name="input_document_type"></a> [document_type](#input_document_type)

Description: The type of document, which decides what can use it. The default is `Command`, for documents that Run Command, State Manager and Maintenance Windows run on managed nodes. Others include `Automation` (runbooks), `Session` (Session Manager preferences and session types), `Package` (software for Distributor, with `attachments`), `Policy` and `ChangeCalendar`. The AWS provider lists every accepted type and rejects any other at plan time.

Changing it deletes the document and creates a new one with the same name.

Type: `string`

Default: `"Command"`

#### <a name="input_region"></a> [region](#input_region)

Description: The AWS Region to create the document in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module. A document can be used only in its own Region. Changing it deletes the document and creates a new one in the new Region.

Type: `string`

Default: `null`

#### <a name="input_target_type"></a> [target_type](#input_target_type)

Description: The kinds of resources the document can run on, as a CloudFormation resource type after a `/`. The default, `/AWS::EC2::Instance`, allows EC2 instances. `/` allows every type. `null` sets no target type; according to the [`CreateDocument` API reference](https://docs.aws.amazon.com/systems-manager/latest/APIReference/API_CreateDocument.html), the document then cannot run on any resource. The AWS provider rejects a value that does not start with `/` at plan time.

Type: `string`

Default: `"/AWS::EC2::Instance"`

#### <a name="input_version_name"></a> [version_name](#input_version_name)

Description: A name for this version of the document, such as `Release12.1`: 3 to 128 letters, numbers, `_`, `-` and `.`. (AWS accepts shorter names, but the AWS provider does not.) The default, `null`, sets none. Each version name must be unique within the document, so change it together with `document_content`; AWS rejects an update that reuses a version name.

Type: `string`

Default: `null`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created, in one object, so that other configurations need only one reference:

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
<!-- END_TF_DOCS -->

## License

This module is licensed under the [Apache License 2.0](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/blob/main/LICENSE). See [NOTICE](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/blob/main/NOTICE) for the copyright notice.

The Automate the Cloud name and logo are not covered by this license.

---

Maintained by [Automate the Cloud](https://automatethe.cloud), a Kentucky 501(c)(3) that teaches cloud infrastructure and helps nonprofits run theirs.
