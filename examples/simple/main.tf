provider "aws" {
  region = local.region
}

locals {
  region = "us-east-1"
  name   = "datadog-fwd-ex-${replace(basename(path.cwd), "_", "-")}"

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-datadog-forwarders"
  }
}

# Note: you will need to create this secret manually prior to running
# This avoids having to pass the key to Terraform in plaintext
data "aws_secretsmanager_secret" "datadog_api_key" {
  name = "datadog/api_key"
}

data "aws_caller_identity" "current" {}

################################################################################
# Module
################################################################################

module "default" {
  source = "../../"

  kms_alias             = aws_kms_alias.datadog.name
  dd_api_key_secret_arn = data.aws_secretsmanager_secret.datadog_api_key.arn

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

resource "random_pet" "this" {
  length = 2
}

resource "aws_kms_key" "datadog" {
  description         = "Datadog KMS CMK"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.datadog_cmk.json

  tags = local.tags
}

data "aws_iam_policy_document" "datadog_cmk" {
  statement {
    sid = "CMKOwnerPolicy"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_alias" "datadog" {
  name          = "alias/datadog/${random_pet.this.id}"
  target_key_id = aws_kms_key.datadog.key_id
}
