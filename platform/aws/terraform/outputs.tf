output "cic-rabbitmq-elb" {
  value = "${aws_elb.elb.dns_name}"
}
