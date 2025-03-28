provider "aws" {
  region = "ap-southeast-1"  # Change to your AWS region
}

# 🔹 Get details of the existing EC2 instance
data "aws_instance" "existing_ec2" {
  instance_id = "i-0a629a21d08492544"  # Replace with your actual instance ID
}

# 🔹 Provisioner to install LAMP stack
resource "null_resource" "install_lamp" {
  connection {
    type        = "ssh"
    user        = "ec2-user"   # Change if using Ubuntu (ubuntu) or another OS
    private_key = file("C:/Users/SouravGhosh/Downloads/TF-EC2-KP.pem")
    host        = data.aws_instance.existing_ec2.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y httpd mariadb105-server php php-mysqlnd",
      "sudo systemctl enable --now httpd",
      "sudo systemctl enable --now mariadb"
    ]
  }
}