variable "access_key" {}
variable "secret_key" {}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "eu-west-1"
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

variable "vault_token" {}

provider "vault" {
  address = "https://vault.cycloid.io"
  token   = "${var.vault_token}"
}

variable "build_team_name" {}
variable "build_pipeline_name" {}
variable "external_worker_image" {}
variable "project" {}
variable "env" {}
variable "customer" {}

# If we want to provide an other path, we have to override it on the pipeline side
variable "worker_keys_path" {
  default = "external_worker_key"
}

# worker_keys_path should dontain ssh_pub and ssh_prv field
data "vault_generic_secret" "worker_keys" {
  path = "cycloid/${var.build_team_name}/${var.worker_keys_path}"
}
