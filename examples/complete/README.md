# Complete

An `Automation` runbook, `example-greeting-runbook`, created in `us-west-2` through the module's `region` input while the provider is configured for `us-east-1`. Its one step runs a Python script, [`files/greet.py`](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/blob/main/examples/complete/files/greet.py), that is attached to the document from a private, encrypted, versioned S3 bucket created in the same run with the [Automate the Cloud S3 bucket module](https://registry.terraform.io/modules/AutomateTheCloud/s3_bucket/aws). The content is built with `jsonencode`, and includes the script's SHA-256 hash in its `files` section, which AWS requires for an attached script. The version is named `1.0.0`.

AWS copies the script into the document version when it is created. To publish a change to the script, edit it and change `version_name` in the same apply: the module then creates version 2 with the new copy, and makes it the default.

## Run it

```shell
terraform init
terraform apply
```

Then run the runbook, and read its output:

```shell
id=$(aws ssm start-automation-execution --region us-west-2 \
  --document-name example-greeting-runbook --parameters Message=Automate \
  --query AutomationExecutionId --output text)
aws ssm get-automation-execution --region us-west-2 --automation-execution-id "$id" \
  --query AutomationExecution.Outputs
```

After a few seconds, the output is `"Greet.Greeting": ["Hello, Automate!"]`.

Remove it with `terraform destroy`. The bucket is created with `force_destroy`, so the destroy also deletes the script in it, with its old versions.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

- <a name="requirement_random"></a> [random](#requirement_random) (~> 3.0)

### Outputs

The following outputs are exported:

#### <a name="output_document"></a> [document](#output_document)

Description: The runbook's name, ARN, Region and default version
<!-- END_TF_DOCS -->
