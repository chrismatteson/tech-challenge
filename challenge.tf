provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

#module "consul" {
#  source = "git::https://github.com/chrismatteson/consul//terraform/aws?ref=terraform_enterprise"
#  key_name = "${var.key_name}"
#  private_key = "${var.private_key}"
#  region   = "us-west-2"
#  servers  = "3"
#}

variable "ami" {}

variable "instance_type" {
  description = "The AWS instance type to use for both clients and servers."
  default     = "t2.micro"
}

variable "key_name" {}

variable "server_count" {
  description = "The number of servers to provision."
  default     = "3"
}

variable "client_count" {
  description = "The number of clients to provision."
  default     = "4"
}

variable "cluster_tag_value" {
  description = "Used by Consul to automatically form a cluster."
  default     = "auto-join"
}

module "hashistack" {
  source = "git::https://github.com/chrismatteson/nomad//terraform/aws/modules/hashistack?ref=challenge"
  region            = "${var.region}"
  ami               = "${var.ami}"
  instance_type     = "${var.instance_type}"
  key_name          = "${var.key_name}"
  server_count      = "${var.server_count}"
  client_count      = "${var.client_count}"
  cluster_tag_value = "${var.cluster_tag_value}"
}

output "IP_Addresses" {
  value = <<CONFIGURATION

Client public IPs: ${join(", ", module.hashistack.client_public_ips)}
Client private IPs: ${join(", ", module.hashistack.client_private_ips)}
Server public IPs: ${join(", ", module.hashistack.primary_server_public_ips)}
Server private IPs: ${join(", ", module.hashistack.primary_server_private_ips)}

To connect, add your private key and SSH into any client or server with
`ssh ubuntu@PUBLIC_IP`. You can test the integrity of the cluster by running:

  $ consul members
  $ nomad server-members
  $ nomad node-status

If you see an error message like the following when running any of the above
commands, it usuallly indicates that the configuration script has not finished
executing:

"Error querying servers: Get http://127.0.0.1:4646/v1/agent/members: dial tcp
127.0.0.1:4646: getsockopt: connection refused"

Simply wait a few seconds and rerun the command if this occurs.

The Consul UI can be accessed at http://PUBLIC_IP:8500/ui.

CONFIGURATION
}

provider "nomad" {
  address = "http://${module.hashistack.primary_server_public_ips[1]}:4646"
}

resource "nomad_job" "terraformweb" {
  jobspec = "${file("${path.module}/terraformweb.hcl")}"
  depends_on = ["module.hashistack"]
}

resource "nomad_job" "fabio" {
  jobspec = "${file("${path.module}/fabio.hcl")}"
  depends_on = ["module.hashistack"]
}

provider "consul" {
  address = "${module.hashistack.primary_server_public_ips[1]}:8500"
}

resource "consul_service" "terraform_website" {
  name = "terraform_website"
  depends_on = ["module.hashistack"]
}
