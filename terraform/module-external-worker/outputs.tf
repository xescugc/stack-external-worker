output "role_worker" {
  value = "${aws_iam_role.worker.arn}"
}

# ASG
output "asg_worker_name" {
  value = "${aws_cloudformation_stack.worker.outputs["AsgName"]}"
}

