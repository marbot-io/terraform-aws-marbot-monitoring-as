terraform {
  required_version = ">= 0.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.66.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.2"
    }
  }
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_autoscaling_group" "asg" {
  name = var.auto_scaling_group_name
}

locals {
  topic_arn = var.create_topic == false ? var.topic_arn : join("", aws_sns_topic.marbot[*].arn)
  tags      = { for tag in data.aws_autoscaling_group.asg.tag : tag.key => tag.value }
  enabled   = var.enabled && lookup(local.tags, "marbot", "on") != "off"

  cpu_utilization                        = lookup(local.tags, "marbot:cpu-utilization", var.cpu_utilization)
  cpu_utilization_threshold              = try(tonumber(lookup(local.tags, "marbot:cpu-utilization:threshold", var.cpu_utilization_threshold)), var.cpu_utilization_threshold)
  cpu_utilization_period_raw             = try(tonumber(lookup(local.tags, "marbot:cpu-utilization:period", var.cpu_utilization_period)), var.cpu_utilization_period)
  cpu_utilization_period                 = min(max(floor(local.cpu_utilization_period_raw / 60) * 60, 60), 86400)
  cpu_utilization_evaluation_periods_raw = try(tonumber(lookup(local.tags, "marbot:cpu-utilization:evaluation-periods", var.cpu_utilization_evaluation_periods)), var.cpu_utilization_evaluation_periods)
  cpu_utilization_evaluation_periods     = min(max(local.cpu_utilization_evaluation_periods_raw, 1), floor(86400 / local.cpu_utilization_period))

  cpu_credit_balance                        = lookup(local.tags, "marbot:cpu-credit-balance", var.cpu_credit_balance)
  cpu_credit_balance_threshold              = try(tonumber(lookup(local.tags, "marbot:cpu-credit-balance:threshold", var.cpu_credit_balance_threshold)), var.cpu_credit_balance_threshold)
  cpu_credit_balance_period_raw             = try(tonumber(lookup(local.tags, "marbot:cpu-credit-balance:period", var.cpu_credit_balance_period)), var.cpu_credit_balance_period)
  cpu_credit_balance_period                 = min(max(floor(local.cpu_credit_balance_period_raw / 60) * 60, 60), 86400)
  cpu_credit_balance_evaluation_periods_raw = try(tonumber(lookup(local.tags, "marbot:cpu-credit-balance:evaluation-periods", var.cpu_credit_balance_evaluation_periods)), var.cpu_credit_balance_evaluation_periods)
  cpu_credit_balance_evaluation_periods     = min(max(local.cpu_credit_balance_evaluation_periods_raw, 1), floor(86400 / local.cpu_credit_balance_period))

  ebs_io_credit_balance                        = lookup(local.tags, "marbot:ebs-io-credit-balance", var.ebs_io_credit_balance)
  ebs_io_credit_balance_threshold              = try(tonumber(lookup(local.tags, "marbot:ebs-io-credit-balance:threshold", var.ebs_io_credit_balance_threshold)), var.ebs_io_credit_balance_threshold)
  ebs_io_credit_balance_period_raw             = try(tonumber(lookup(local.tags, "marbot:ebs-io-credit-balance:period", var.ebs_io_credit_balance_period)), var.ebs_io_credit_balance_period)
  ebs_io_credit_balance_period                 = min(max(floor(local.ebs_io_credit_balance_period_raw / 60) * 60, 60), 86400)
  ebs_io_credit_balance_evaluation_periods_raw = try(tonumber(lookup(local.tags, "marbot:ebs-io-credit-balance:evaluation-periods", var.ebs_io_credit_balance_evaluation_periods)), var.ebs_io_credit_balance_evaluation_periods)
  ebs_io_credit_balance_evaluation_periods     = min(max(local.ebs_io_credit_balance_evaluation_periods_raw, 1), floor(86400 / local.ebs_io_credit_balance_period))

  ebs_throughput_credit_balance                        = lookup(local.tags, "marbot:ebs-throughput-credit-balance", var.ebs_throughput_credit_balance)
  ebs_throughput_credit_balance_threshold              = try(tonumber(lookup(local.tags, "marbot:ebs-throughput-credit-balance:threshold", var.ebs_throughput_credit_balance_threshold)), var.ebs_throughput_credit_balance_threshold)
  ebs_throughput_credit_balance_period_raw             = try(tonumber(lookup(local.tags, "marbot:ebs-throughput-credit-balance:period", var.ebs_throughput_credit_balance_period)), var.ebs_throughput_credit_balance_period)
  ebs_throughput_credit_balance_period                 = min(max(floor(local.ebs_throughput_credit_balance_period_raw / 60) * 60, 60), 86400)
  ebs_throughput_credit_balance_evaluation_periods_raw = try(tonumber(lookup(local.tags, "marbot:ebs-throughput-credit-balance:evaluation-periods", var.ebs_throughput_credit_balance_evaluation_periods)), var.ebs_throughput_credit_balance_evaluation_periods)
  ebs_throughput_credit_balance_evaluation_periods     = min(max(local.ebs_throughput_credit_balance_evaluation_periods_raw, 1), floor(86400 / local.ebs_throughput_credit_balance_period))
}



##########################################################################
#                                                                        #
#                                 TOPIC                                  #
#                                                                        #
##########################################################################

resource "aws_sns_topic" "marbot" {
  count = (var.create_topic && local.enabled) ? 1 : 0

  name_prefix = "marbot"
  tags        = var.tags
}

resource "aws_sns_topic_policy" "marbot" {
  count = (var.create_topic && local.enabled) ? 1 : 0

  arn    = join("", aws_sns_topic.marbot[*].arn)
  policy = data.aws_iam_policy_document.topic_policy.json
}

data "aws_iam_policy_document" "topic_policy" {
  statement {
    sid       = "Sid1"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [join("", aws_sns_topic.marbot[*].arn)]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
      ]
    }
  }

  statement {
    sid       = "Sid2"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [join("", aws_sns_topic.marbot[*].arn)]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_subscription" "marbot" {
  depends_on = [aws_sns_topic_policy.marbot]
  count      = (var.create_topic && local.enabled) ? 1 : 0

  topic_arn              = join("", aws_sns_topic.marbot[*].arn)
  protocol               = "https"
  endpoint               = "https://api.marbot.io/${var.stage}/endpoint/${var.endpoint_id}"
  endpoint_auto_confirms = true
  delivery_policy        = <<JSON
{
  "healthyRetryPolicy": {
    "minDelayTarget": 1,
    "maxDelayTarget": 60,
    "numRetries": 100,
    "numNoDelayRetries": 0,
    "backoffFunction": "exponential"
  },
  "throttlePolicy": {
    "maxReceivesPerSecond": 1
  }
}
JSON
}



resource "aws_cloudwatch_event_rule" "monitoring_jump_start_connection" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (var.module_version_monitoring_enabled && local.enabled) ? 1 : 0

  name                = "marbot-asg-connection-${random_id.id8.hex}"
  description         = "Monitoring Jump Start connection. (created by marbot)"
  schedule_expression = "rate(30 days)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "monitoring_jump_start_connection" {
  count = (var.module_version_monitoring_enabled && local.enabled) ? 1 : 0

  rule      = join("", aws_cloudwatch_event_rule.monitoring_jump_start_connection[*].name)
  target_id = "marbot"
  arn       = local.topic_arn
  input     = <<JSON
{
  "Type": "monitoring-jump-start-tf-connection",
  "Module": "asg",
  "Version": "1.0.0",
  "Partition": "${data.aws_partition.current.partition}",
  "AccountId": "${data.aws_caller_identity.current.account_id}",
  "Region": "${data.aws_region.current.name}"
}
JSON
}

##########################################################################
#                                                                        #
#                                 ALARMS                                 #
#                                                                        #
##########################################################################

resource "random_id" "id8" {
  byte_length = 8
}



resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.cpu_utilization == "static" && local.enabled) ? 1 : 0

  alarm_name          = "marbot-asg-cpu-utilization-${random_id.id8.hex}"
  alarm_description   = "Average CPU utilization too high. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = local.cpu_utilization_period
  evaluation_periods  = local.cpu_utilization_evaluation_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = local.cpu_utilization_threshold
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    AutoScalingGroupName = var.auto_scaling_group_name
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}



resource "aws_cloudwatch_metric_alarm" "cpu_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.cpu_credit_balance == "static" && local.enabled) ? 1 : 0

  alarm_name          = "marbot-asg-cpu-credit-balance-${random_id.id8.hex}"
  alarm_description   = "Average CPU credit balance too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "CPUCreditBalance"
  statistic           = "Average"
  period              = local.cpu_credit_balance_period
  evaluation_periods  = local.cpu_credit_balance_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = local.cpu_credit_balance_threshold
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    AutoScalingGroupName = var.auto_scaling_group_name
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}



resource "aws_cloudwatch_metric_alarm" "ebs_io_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.ebs_io_credit_balance == "static" && local.enabled) ? 1 : 0

  alarm_name          = "marbot-asg-ebs-io-credit-balance-${random_id.id8.hex}"
  alarm_description   = "Average EBS IO credit balance too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "EBSIOBalance%"
  statistic           = "Average"
  period              = local.ebs_io_credit_balance_period
  evaluation_periods  = local.ebs_io_credit_balance_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = local.ebs_io_credit_balance_threshold
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    AutoScalingGroupName = var.auto_scaling_group_name
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}



resource "aws_cloudwatch_metric_alarm" "ebs_throughput_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.ebs_throughput_credit_balance == "static" && local.enabled) ? 1 : 0

  alarm_name          = "marbot-asg-ebs-throughput-credit-balance-${random_id.id8.hex}"
  alarm_description   = "Average EBS throughput credit balance too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "EBSByteBalance%"
  statistic           = "Average"
  period              = local.ebs_throughput_credit_balance_period
  evaluation_periods  = local.ebs_throughput_credit_balance_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = local.ebs_throughput_credit_balance_threshold
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    AutoScalingGroupName = var.auto_scaling_group_name
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}



# TODO add alarm for network in+out



resource "aws_cloudwatch_event_rule" "unsuccessful" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = local.enabled ? 1 : 0

  name          = "marbot-asg-unsuccessful-${random_id.id8.hex}"
  description   = "EC2 Auto Scaling failed to launch or terminate an instance. (created by marbot)"
  tags          = var.tags
  event_pattern = <<JSON
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance Launch Unsuccessful",
    "EC2 Instance Terminate Unsuccessful",
    "EC2 Auto Scaling Instance Refresh Failed"
  ],
  "detail": {
    "AutoScalingGroupName": [
      "${var.auto_scaling_group_name}"
    ]
  }
}
JSON
}

resource "aws_cloudwatch_event_target" "unsuccessful" {
  count = local.enabled ? 1 : 0

  rule      = join("", aws_cloudwatch_event_rule.unsuccessful[*].name)
  target_id = "marbot"
  arn       = local.topic_arn
}
