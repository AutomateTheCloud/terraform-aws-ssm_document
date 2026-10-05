# Basic SSM document

A `Command` document, read from [`files/hello_world.yaml`](https://github.com/AutomateTheCloud/terraform-aws-ssm_document/blob/main/examples/basic/files/hello_world.yaml), that prints a message on Linux EC2 instances. It uses only the module's required inputs, so it is a YAML document that can run on EC2 instances, shared with no one, in the provider's Region (`us-east-1`).

Creating the document runs nothing. To run it on instances that Systems Manager manages, use Run Command:

```shell
aws ssm send-command --region us-east-1 --document-name example-hello-world \
  --targets Key=tag:Role,Values=web --parameters message="Hello from Run Command"
```

## Run it

```shell
terraform init
terraform apply
```

Remove it with `terraform destroy`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Outputs

The following outputs are exported:

#### <a name="output_document"></a> [document](#output_document)

Description: The document's name, ARN and default version
<!-- END_TF_DOCS -->
