 terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
region = "us-east-1"
access_key = "**************"
secret_key =  "**************"

}

resource "aws_launch_configuration" "project" {
  image_id        = "ami-40d28157"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  # Required when using a launch configuration with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }
  }

data "aws_availability_zones" "all" {}

resource "aws_autoscaling_group" "project" {
  launch_configuration = "${aws_launch_configuration.project.id}"
  availability_zones = "${data.aws_availability_zones.all.names}"
  load_balancers = ["${aws_elb.project.name}"]
  health_check_type = "ELB"

  min_size =  2
  max_size =  5

  tag {
    key = "name"
    value = "terraform-asg-project"
    propagate_at_launch = true
  }
  
}






resource "aws_security_group" "instance" {
  name = "terraform-project"

   ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    lifecycle {
    create_before_destroy = true
  }
}



resource "aws_security_group" "elb" {
name = "terraform-project-elb"
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress {
  from_port = 0
  to_port = 0
  protocol =  "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_elb" "project" {
name = "terraform-asg-project"
availability_zones = "${data.aws_availability_zones.all.names}"
security_groups = ["${aws_security_group.elb.id}"]

listener {
lb_port = 80
lb_protocol = "http"
instance_port = "${var.server_port}"
instance_protocol = "http"
}
health_check {
healthy_threshold = 2
unhealthy_threshold = 2
timeout = 3
interval = 30
target = "HTTP:${var.server_port}/"
}
}
