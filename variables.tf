variable "document_content" {
  description = "The JSON or YAML content of the document"
  type        = string
  default     = ""
}

variable "document_format" {
  description = "The format of the document. (JSON, YAML)"
  type        = string
  default     = "YAML"
}

variable "document_type" {
  description = "The type of the document (Automation, Command, Package, Policy, Session)"
  type        = string
  default     = "Command"
}

variable "name" {
  description = "The name of the document"
  type        = string
  default     = ""
}

variable "target_type" {
  description = "The target type which defines the kinds of resources the document can run on"
  type        = string
  default     = "/AWS::EC2::Instance"
}
