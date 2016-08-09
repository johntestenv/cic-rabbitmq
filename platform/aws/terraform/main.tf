provider "aws" {
  region = "${var.aws_region}"
}

resource "terraform_remote_state" "acct" {
  backend = "s3"
  config {
    bucket = "${var.acct_remote_state_bucket}"
    key = "${var.acct_remote_state_key}"
    region = "${var.aws_region}"
  }
}

resource "terraform_remote_state" "network" {
  backend = "s3"
  config {
    bucket = "${var.network_remote_state_bucket}"
    key = "${var.network_remote_state_key}"
    region = "${var.aws_region}"
  }
}

resource "aws_key_pair" "cic-rabbitmq" {
  key_name = "cic-rabbitmq"
  public_key = "${var.public_key}"
}

resource "aws_instance" "cic-rabbitmq" {
  ami = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  key_name = "${aws_key_pair.cic-rabbitmq.key_name}"
  vpc_security_group_ids = ["${aws_security_group.cic-rabbitmq-instance.id}","${terraform_remote_state.network.output.baselinesg}"]
  subnet_id = "${element(split(",", terraform_remote_state.network.output.priv_subnets), 1)}"
  user_data = "${file("../../../data/templates/userdata.sh.tpl")}"
}

resource "aws_elb" "elb" {
  name = "cic-rabbitmq-elb"
  subnets = ["${split(",", terraform_remote_state.network.output.pub_subnets)}"]
  security_groups = ["${aws_security_group.cic-rabbitmq-elb.id}","${terraform_remote_state.network.output.baselinesg}"]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "TCP:80"
    interval = 30
  }
  instances = ["${aws_instance.cic-rabbitmq.id}"]
  idle_timeout = 400
}

resource "aws_security_group" "cic-rabbitmq-elb" {
  name = "cic-rabbitmq"
  description = "public cic-rabbitmq access for demo"
  vpc_id = "${terraform_remote_state.network.output.vpc_id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["${var.my_ip}"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "cic-rabbitmq-instance" {
  name = "cic-rabbitmq"
  description = "public cic-rabbitmq access for demo"
  vpc_id = "${terraform_remote_state.network.output.vpc_id}"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = ["${aws_security_group.cic-rabbitmq-elb.id}","${terraform_remote_state.network.output.baselinesg}"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}