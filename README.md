# Auto Scaling Group monitoring

Connects you to CloudWatcgh Events of a particular Auto Scaling Group, adds alarms to monitor CPU and storage, and forwards them to Slack managed by [marbot](https://marbot.io/).

## Usage

1. Create a new directory
2. Within the new directory, create a file `main.tf` with the following content:
```
provider "aws" {}

module "marbot-monitoring-asg" {
  source   = "marbot-io/marbot-monitoring-asg/aws"
  #version = "x.y.z"         # we recommend to pin the version

  endpoint_id              = "" # to get this value, select a Slack channel where marbot belongs to and send a message like this: "@marbot show me my endpoint id"
  auto_scaling_group_name  = "" # the ASG name
}
```
3. Run the following commands:
```
terraform init
terraform apply
```

## Update procedure

1. Update the `version`
2. Run the following commands:
```
terraform get
terraform apply
```

## License
All modules are published under Apache License Version 2.0.

## About
A [marbot.io](https://marbot.io/) project. Engineered by [widdix](https://widdix.net).
