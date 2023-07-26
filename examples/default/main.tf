terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.66.0"
    }
  }
}

module "marbot-monitoring-asg" {
  source = "../../"

  endpoint_id             = var.endpoint_id
  auto_scaling_group_name = var.auto_scaling_group_name
}