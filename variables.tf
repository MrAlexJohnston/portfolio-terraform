data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = "github-token"
}

variable "vpc_name" {
  description   = "The name of the VPC"
  type          = string
  default       = "TerraformVPC"
}