###

# worker

###

resource "aws_security_group" "worker" {
  name        = "${var.project}-worker-${var.env}"
  description = "Front ${var.env} for ${var.project}"
  vpc_id      = "${var.vpc_id}"

  #  ingress {
  #    from_port       = 80
  #    to_port         = 80
  #    protocol        = "tcp"
  #    security_groups = ["${aws_security_group.alb-worker.id}"]
  #  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    cycloid.io = "true"
    Name       = "${var.project}-worker-${var.env}"
    env        = "${var.env}"
    project    = "${var.project}"
    role       = "worker"
  }
}

resource "aws_launch_template" "worker" {
  name_prefix = "${var.project}_${var.env}_version_"

  image_id      = "${data.aws_ami.worker.id}"
  instance_type = "${var.worker_type}"
  user_data     = "${base64encode(data.template_file.user_data_worker.rendered)}"
  key_name      = "${var.keypair_name}"

  instance_market_options {
    market_type = "spot"

    spot_options {
      spot_instance_type = "one-time"
      max_price          = "${var.worker_spot_price}"
    }
  }

  network_interfaces {
    associate_public_ip_address = "${var.worker_associate_public_ip_address}"

    security_groups = ["${compact(list(
        "${var.bastion_sg_allow}",
        "${aws_security_group.worker.id}",
        "${var.metrics_sg_allow}",
      ))}"]
  }

  lifecycle {
    create_before_destroy = true
  }

  ebs_optimized = "${var.worker_ebs_optimized}"

  iam_instance_profile {
    name = "${aws_iam_instance_profile.worker_profile.name}"
  }

  tags {
    cycloid.io = "true"
    Name       = "${var.project}-workertemplate-${var.env}"
    client     = "${var.customer}"
    env        = "${var.env}"
    project    = "${var.project}"
    role       = "workertemplate"
  }

  tag_specifications {
    resource_type = "instance"

    tags {
      cycloid.io = "true"
      Name       = "${var.project}-worker-${var.env}"
      client     = "${var.customer}"
      env        = "${var.env}"
      project    = "${var.project}"
      role       = "worker"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags {
      cycloid.io = "true"
      Name       = "${var.project}-worker-${var.env}"
      client     = "${var.customer}"
      env        = "${var.env}"
      project    = "${var.project}"
      role       = "worker"
    }
  }

  block_device_mappings {
    device_name = "xvda"

    ebs {
      volume_size           = "${var.worker_disk_size}"
      volume_type           = "${var.worker_disk_type}"
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name  = "/dev/xvdf"
    virtual_name = "container_datas"

    ebs {
      volume_size           = "${var.worker_volume_disk_size}"
      volume_type           = "${var.worker_volume_disk_type}"
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name  = "/dev/xvdg"
    virtual_name = "ephemeral0"
  }

  block_device_mappings {
    device_name  = "/dev/xvdh"
    virtual_name = "ephemeral1"
  }

  block_device_mappings {
    device_name  = "/dev/xvdi"
    virtual_name = "ephemeral2"
  }

  block_device_mappings {
    device_name  = "/dev/xvdj"
    virtual_name = "ephemeral3"
  }

  block_device_mappings {
    device_name  = "/dev/xvdk"
    virtual_name = "ephemeral4"
  }

  block_device_mappings {
    device_name  = "/dev/xvdl"
    virtual_name = "ephemeral5"
  }

  block_device_mappings {
    device_name  = "/dev/xvdm"
    virtual_name = "ephemeral6"
  }

  block_device_mappings {
    device_name  = "/dev/xvdn"
    virtual_name = "ephemeral7"
  }
}

# if needed, define the same template without spot instance
resource "aws_launch_template" "worker_ondemand" {
  name_prefix = "${var.project}_ondemand_${var.env}_version_"

  image_id      = "${data.aws_ami.worker.id}"
  instance_type = "${var.worker_type}"
  user_data     = "${base64encode(data.template_file.user_data_worker.rendered)}"
  key_name      = "${var.keypair_name}"

  network_interfaces {
    associate_public_ip_address = "${var.worker_associate_public_ip_address}"

    security_groups = ["${compact(list(
        "${var.bastion_sg_allow}",
        "${aws_security_group.worker.id}",
        "${var.metrics_sg_allow}",
      ))}"]
  }

  lifecycle {
    create_before_destroy = true
  }

  ebs_optimized = "${var.worker_ebs_optimized}"

  iam_instance_profile {
    name = "${aws_iam_instance_profile.worker_profile.name}"
  }

  tags {
    cycloid.io = "true"
    Name       = "${var.project}-workertemplate-${var.env}"
    client     = "${var.customer}"
    env        = "${var.env}"
    project    = "${var.project}"
    role       = "workertemplate"
  }

  tag_specifications {
    resource_type = "instance"

    tags {
      cycloid.io = "true"
      Name       = "${var.project}-worker-${var.env}"
      client     = "${var.customer}"
      env        = "${var.env}"
      project    = "${var.project}"
      role       = "worker"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags {
      cycloid.io = "true"
      Name       = "${var.project}-worker-${var.env}"
      client     = "${var.customer}"
      env        = "${var.env}"
      project    = "${var.project}"
      role       = "worker"
    }
  }

  block_device_mappings {
    device_name = "xvda"

    ebs {
      volume_size           = "${var.worker_disk_size}"
      volume_type           = "${var.worker_disk_type}"
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name  = "/dev/xvdf"
    virtual_name = "container_datas"

    ebs {
      volume_size           = "${var.worker_volume_disk_size}"
      volume_type           = "${var.worker_volume_disk_type}"
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name  = "/dev/xvdg"
    virtual_name = "ephemeral0"
  }

  block_device_mappings {
    device_name  = "/dev/xvdh"
    virtual_name = "ephemeral1"
  }

  block_device_mappings {
    device_name  = "/dev/xvdi"
    virtual_name = "ephemeral2"
  }

  block_device_mappings {
    device_name  = "/dev/xvdj"
    virtual_name = "ephemeral3"
  }

  block_device_mappings {
    device_name  = "/dev/xvdk"
    virtual_name = "ephemeral4"
  }

  block_device_mappings {
    device_name  = "/dev/xvdl"
    virtual_name = "ephemeral5"
  }

  block_device_mappings {
    device_name  = "/dev/xvdm"
    virtual_name = "ephemeral6"
  }

  block_device_mappings {
    device_name  = "/dev/xvdn"
    virtual_name = "ephemeral7"
  }
}

###

# ASG

###

resource "aws_cloudformation_stack" "worker" {
  name = "${var.project}-worker-${var.env}"

  template_body = <<EOF
{
  "Resources": {
    "externalWorkers${var.env}": {
      "Type": "AWS::AutoScaling::AutoScalingGroup",
      "Properties": {
        "AvailabilityZones": ${jsonencode(var.zones)},
        "VPCZoneIdentifier": ${jsonencode(var.public_subnets_ids)},
        "LaunchTemplate": {
            "LaunchTemplateId": "${aws_launch_template.worker.id}",
            "Version" : "${aws_launch_template.worker.latest_version}"
        },
        "MaxSize": "${var.worker_asg_max_size}",
        "DesiredCapacity" : "${var.worker_count}",
        "MinSize": "${var.worker_asg_min_size}",
        "TerminationPolicies": ["OldestLaunchConfiguration", "NewestInstance"],
        "HealthCheckType": "EC2",
        "HealthCheckGracePeriod": 600,
        "Tags" : [
          { "Key" : "Name", "Value" : "${var.project}-worker-${lookup(var.short_region, data.aws_region.current.name)}-${var.env}", "PropagateAtLaunch" : "true" },
          { "Key" : "client", "Value" : "${var.customer}", "PropagateAtLaunch" : "true" },
          { "Key" : "env", "Value" : "${var.env}", "PropagateAtLaunch" : "true" },
          { "Key" : "project", "Value" : "${var.project}", "PropagateAtLaunch" : "true" },
          { "Key" : "role", "Value" : "worker", "PropagateAtLaunch" : "true" },
          { "Key" : "cycloid.io", "Value" : "true", "PropagateAtLaunch" : "true" }
        ]
      },
      "UpdatePolicy": {
        "AutoScalingRollingUpdate": {
          "MinInstancesInService": "0",
          "MinSuccessfulInstancesPercent": "50",
          "SuspendProcesses": ["ScheduledActions"],
          "MaxBatchSize": "2",
          "PauseTime": "PT8M",
          "WaitOnResourceSignals": "true"
        }
      }
    }
  },
  "Outputs": {
    "AsgName": {
      "Description": "The name of the auto scaling group",
       "Value": {"Ref": "externalWorkers${var.env}"}
    }
  }
}
EOF
}

# Cloudwatch autoscaling


# Disable for now as concourse don't really like scale down
#resource "aws_autoscaling_policy" "worker-scale-up" {
#  name                   = "${var.project}-worker-scale-up-${var.env}"
#  scaling_adjustment     = "${var.worker_asg_scale_up_scaling_adjustment}"
#  adjustment_type        = "ChangeInCapacity"
#  cooldown               = "${var.worker_asg_scale_up_cooldown}"
#  autoscaling_group_name = "${aws_cloudformation_stack.worker.outputs["AsgName"]}"
#}
#
#resource "aws_cloudwatch_metric_alarm" "worker-scale-up" {
#  alarm_name          = "${var.project}-worker-scale-up-${var.env}"
#  comparison_operator = "GreaterThanOrEqualToThreshold"
#  evaluation_periods  = "2"
#  metric_name         = "CPUUtilization"
#  namespace           = "AWS/EC2"
#  period              = "120"
#  statistic           = "Average"
#  threshold           = "${var.worker_asg_scale_up_threshold}"
#
#  dimensions {
#    AutoScalingGroupName = "${aws_cloudformation_stack.worker.outputs["AsgName"]}"
#  }
#
#  alarm_description = "This metric monitor ec2 cpu utilization on ${var.project} ${var.env}"
#  alarm_actions     = ["${aws_autoscaling_policy.worker-scale-up.arn}"]
#}
#
#resource "aws_autoscaling_policy" "worker-scale-down" {
#  name                   = "${var.project}-worker-scale-down-${var.env}"
#  scaling_adjustment     = "${var.worker_asg_scale_down_scaling_adjustment}"
#  adjustment_type        = "ChangeInCapacity"
#  cooldown               = "${var.worker_asg_scale_down_cooldown}"
#  autoscaling_group_name = "${aws_cloudformation_stack.worker.outputs["AsgName"]}"
#}
#
#resource "aws_cloudwatch_metric_alarm" "worker-scale-down" {
#  alarm_name          = "${var.project}-worker-scale-down-${var.env}"
#  comparison_operator = "LessThanOrEqualToThreshold"
#  evaluation_periods  = "2"
#  metric_name         = "CPUUtilization"
#  namespace           = "AWS/EC2"
#  period              = "120"
#  statistic           = "Average"
#  threshold           = "${var.worker_asg_scale_down_threshold}"
#
#  dimensions {
#    AutoScalingGroupName = "${aws_cloudformation_stack.worker.outputs["AsgName"]}"
#  }
#
#  alarm_description = "This metric monitor ec2 cpu utilization on ${var.project} ${var.env}"
#  alarm_actions     = ["${aws_autoscaling_policy.worker-scale-down.arn}"]
#}

