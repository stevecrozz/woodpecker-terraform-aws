# -----------------------------------------------------------------------------
# EC2 Agents managed by Woodpecker Autoscaler
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IAM Role for EC2 Agent Instances
# -----------------------------------------------------------------------------

resource "aws_iam_role" "agent_instance" {
  name = "${var.project_name}-agent-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "agent_instance" {
  name = "${var.project_name}-agent-instance-policy"
  role = aws_iam_role.agent_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.agent.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.woodpecker_agent_secret.arn
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "agent" {
  name = "${var.project_name}-agent-instance-profile"
  role = aws_iam_role.agent_instance.name
}

# -----------------------------------------------------------------------------
# Security Group for EC2 Agents
# -----------------------------------------------------------------------------

resource "aws_security_group" "agent_ec2" {
  name        = "${var.project_name}-agent-ec2-sg"
  description = "Security group for EC2 agent instances"
  vpc_id      = aws_vpc.main.id

  # No inbound rules needed - agents only make outbound connections

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-agent-ec2-sg"
  }
}

# -----------------------------------------------------------------------------
# Get Latest Amazon Linux 2023 AMI
# -----------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Launch Template for Agent Instances
# -----------------------------------------------------------------------------

resource "aws_launch_template" "agent" {
  name_prefix   = "${var.project_name}-agent-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.agent_instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.agent.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.agent_ec2.id]
    subnet_id                   = aws_subnet.private[0].id
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install Docker
    dnf install -y docker
    systemctl enable docker
    systemctl start docker

    # Get agent secret from Secrets Manager
    AGENT_SECRET=$(aws secretsmanager get-secret-value \
      --secret-id ${aws_secretsmanager_secret.woodpecker_agent_secret.id} \
      --query SecretString \
      --output text \
      --region ${var.aws_region})

    # Run Woodpecker Agent
    docker run -d \
      --name woodpecker-agent \
      --restart always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -e WOODPECKER_SERVER=server.${var.project_name}.local:9000 \
      -e WOODPECKER_AGENT_SECRET=$AGENT_SECRET \
      -e WOODPECKER_MAX_WORKFLOWS=${var.agent_max_workflows} \
      -e WOODPECKER_LOG_LEVEL=info \
      woodpeckerci/woodpecker-agent:${var.woodpecker_version}
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-agent"
    }
  }

  tags = {
    Name = "${var.project_name}-agent-template"
  }

  lifecycle {
    create_before_destroy = true
  }
}
