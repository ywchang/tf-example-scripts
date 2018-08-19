variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {
  default = "PluralsightKeys"
}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "ap-southeast-1"
}

resource "aws_instance" "nginx" {
  ami           = "ami-01da99628f381e50a"
  instance_type = "t2.micro"
  key_name        = "${var.key_name}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install nginx1.12 -y",
      "sudo service nginx start"
    ]
  }
}

output "aws_instance_public_dns" {
    value = "${aws_instance.nginx.public_dns}"
}