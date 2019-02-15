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
