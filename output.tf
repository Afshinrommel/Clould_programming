output "elb_dns_name" {
value = "${aws_elb.project.dns_name}"  
}