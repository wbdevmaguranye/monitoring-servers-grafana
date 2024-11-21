# Create an S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "monitoring-backend-prodmagz" # Use hyphens instead of underscores

  tags = {
    Name        = "TerraformStateBucket"
    Environment = "Production"
  }
}

# Save the private key locally
resource "local_file" "private_key" {
  content  = file("${path.module}/monitoring") # Load the existing private key
  filename = "${path.module}/generated-key.pem" # Save as a .pem file in the same directory
}

# Create a Key Pair in AWS
resource "aws_key_pair" "generated_key" {
  key_name   = var.monitoring_key
  public_key = file("${path.module}/monitoring.pub") # Path to monitoring.pub in the same directory
}

# Security Group for Prometheus
resource "aws_security_group" "prometheus_sg" {
  name        = "PrometheusSG"
  description = "Allow ports for Prometheus and SSH"

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow Prometheus access from all IPs
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from any IP (adjust as needed)
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true # Allow SSH from other instances in this SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }
}

# Security Group for Grafana
resource "aws_security_group" "grafana_sg" {
  name        = "GrafanaSG"
  description = "Allow ports for Grafana and SSH"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow Grafana access from all IPs
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from any IP (adjust as needed)
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true # Allow SSH from other instances in this SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }
}

# Prometheus Instance
resource "aws_instance" "prometheus_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.prometheus_sg.id]

  tags = {
    Name = "Prometheus-Server"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/monitoring") # Reference to private key
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y prometheus"
    ]
  }
}

# Grafana Instance (with t2.medium instance type)
resource "aws_instance" "grafana_server" {
  ami                    = var.ami_id
  instance_type          = "t2.medium" # Updated to use t2.medium
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]

  tags = {
    Name = "Grafana-Server"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/monitoring") # Reference to private key
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y software-properties-common wget",
      "wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -",
      "sudo add-apt-repository \"deb https://packages.grafana.com/oss/deb stable main\"",
      "sudo apt update",
      "sudo apt install -y grafana",
      "sudo systemctl start grafana-server",
      "sudo systemctl enable grafana-server"
    ]
  }
}
