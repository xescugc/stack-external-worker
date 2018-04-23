resource "aws_ecs_cluster" "ecs" {
  name = "${var.project}-ecs-cluster-${var.env}"
}


resource "aws_ecs_service" "worker" {
  name            = "${var.project}-worker-${var.env}"
  cluster         = "${aws_ecs_cluster.ecs.id}"
  task_definition = "${aws_ecs_task_definition.worker.arn}"
  desired_count   = "${var.worker_svc_count}"
}

# If we want to limit the cpu/memory
#    "cpu": 1,
#    "memory": 6000,
locals {
  formated_worker_ssh_prv = "${replace(var.worker_ssh_prv,"\n","\\\\n")}"
}

resource "aws_ecs_task_definition" "worker" {
  family                = "${var.project}-worker-task-def-${var.env}"
  container_definitions = <<EOF
[
  {
    "name": "cycloid-io-external-worker",
    "image": "${var.external_worker_image}",
    "essential": true,
    "memoryReservation": 1000,
    "portMappings": [{
        "containerPort": 55535,
        "hostPort": 55535
    }],
    "privileged": true,
    "entryPoint": [ "/bin/sh" ],
    "command": [
       "-c",
       "echo $$RAW_PUBLIC_KEY > /etc/CONCOURSE_TSA_PUBLIC_KEY;   echo $$RAW_PRIVATE_KEY > /etc/CONCOURSE_TSA_WORKER_PRIVATE_KEY;   echo \"$(date +%Y-%m-%d-%H%M%S) - concourse retire-worker\";   while ! concourse retire-worker --name=$${HOSTNAME} | grep -q worker-not-found; do   echo \".... Try to retire\";   sleep 5;   done;   echo \"$(date +%Y-%m-%d-%H%M%S) - concourse worker\";   /usr/local/bin/dumb-init /usr/local/bin/concourse worker --name=$HOSTNAME --baggageclaim-driver=btrfs"
    ],
    "environment": [
       {"name": "CONCOURSE_TSA_HOST", "value": "${var.scheduler_host}"},
       {"name": "CONCOURSE_TSA_PORT", "value": "${var.scheduler_port}"},
       {"name": "CONCOURSE_TSA_PUBLIC_KEY", "value": "/etc/CONCOURSE_TSA_PUBLIC_KEY"},
       {"name": "RAW_PUBLIC_KEY", "value": "${var.worker_ssh_pub}"},
       {"name": "RAW_PRIVATE_KEY", "value": "${local.formated_worker_ssh_prv}"},
       {"name": "CONCOURSE_TSA_WORKER_PRIVATE_KEY", "value": "/etc/CONCOURSE_TSA_WORKER_PRIVATE_KEY"},
       {"name": "CONCOURSE_GARDEN_LOG_LEVEL", "value": "error"},
       {"name": "CONCOURSE_GARDEN_MAX_CONTAINERS", "value": "400"},
       {"name": "CONCOURSE_GARDEN_NETWORK_POOL", "value": "10.254.0.0/20"},
       {"name": "CONCOURSE_GARDEN_DEFAULT_GRACE_TIME", "value": "120"},
       {"name": "CONCOURSE_GARDEN_DESTROY_CONTAINERS_ON_STARTUP", "value": "true"},
       {"name": "CONCOURSE_GARDEN_CLEANUP_PROCESS_DIRS_ON_WAIT", "value": "true"},
       {"name": "CONCOURSE_BAGGAGECLAIM_LOG_LEVEL", "value": "error"}
     ]
  }
]
EOF
  #container_definitions = "${data.template_file.worker.rendered}"
}

# Generate the commandline : ($$ to escape terraform vars)
#
# echo '
#   echo $$RAW_PUBLIC_KEY > /etc/CONCOURSE_TSA_PUBLIC_KEY;
#   echo $$RAW_PRIVATE_KEY > /etc/CONCOURSE_TSA_WORKER_PRIVATE_KEY;
#   echo \"$(date +%Y-%m-%d-%H%M%S) - concourse retire-worker\";
#   while ! concourse retire-worker --name=$${HOSTNAME} | grep -q worker-not-found; do
#   echo \".... Try to retire\";
#   sleep 5;
#   done;
#   echo \"$(date +%Y-%m-%d-%H%M%S) - concourse worker\";
#   /usr/local/bin/dumb-init /usr/local/bin/concourse worker --name=$HOSTNAME --baggageclaim-driver=btrfs
# ' | tr '\n' ' '


#/usr/local/bin/dumb-init /usr/local/bin/concourse worker --name=$HOSTNAME --baggageclaim-driver=btrfs | tee -a /tmp/.liveness_probe
