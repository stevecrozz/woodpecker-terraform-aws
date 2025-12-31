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
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          # Pull images
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          # Push images
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*"
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

