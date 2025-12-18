# -----------------------------------------------------------------------------
# Woodpecker Autoscaler
# Manages EC2 agent instances based on job queue depth
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IAM Role for Autoscaler Task
# -----------------------------------------------------------------------------

resource "aws_iam_role" "autoscaler_task" {
  name = "${var.project_name}-autoscaler-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "autoscaler_ec2" {
  name = "${var.project_name}-autoscaler-ec2-policy"
  role = aws_iam_role.autoscaler_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.agent_instance.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for Autoscaler
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "autoscaler" {
  name              = "/ecs/${var.project_name}/autoscaler"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-autoscaler-logs"
  }
}

# -----------------------------------------------------------------------------
# Autoscaler Configuration stored in SSM Parameter
# -----------------------------------------------------------------------------

resource "aws_ssm_parameter" "autoscaler_config" {
  name = "/${var.project_name}/autoscaler/config"
  type = "String"
  value = yamlencode({
    log_level = "info"

    server = {
      addr  = "server.${var.project_name}.local:9000"
      token = "$WOODPECKER_AGENT_SECRET" # Will be substituted at runtime
    }

    agents = {
      min = 0
      max = var.agent_max_count
    }

    workflows = {
      min             = 0
      max             = var.agent_max_count * var.agent_max_workflows
      per_agent       = var.agent_max_workflows
      labels_strategy = "default"
    }

    pool = {
      min = 0
    }

    provider = {
      type = "aws"
      aws = {
        region            = var.aws_region
        instance_type     = var.agent_instance_type
        image_id          = data.aws_ami.amazon_linux_2023.id
        subnet_id         = aws_subnet.private[0].id
        security_group_id = aws_security_group.agent_ec2.id
        iam_profile_arn   = aws_iam_instance_profile.agent.arn
        user_data_base64  = aws_launch_template.agent.user_data
        tags = {
          Name      = "${var.project_name}-agent"
          ManagedBy = "woodpecker-autoscaler"
        }
      }
    }
  })

  tags = {
    Name = "${var.project_name}-autoscaler-config"
  }
}

# -----------------------------------------------------------------------------
# Autoscaler Task Definition
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "autoscaler" {
  family                   = "${var.project_name}-autoscaler"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.autoscaler_task.arn

  container_definitions = jsonencode([
    {
      name      = "woodpecker-autoscaler"
      image     = "woodpeckerci/autoscaler:latest"
      essential = true

      environment = [
        {
          name  = "WOODPECKER_LOG_LEVEL"
          value = "info"
        },
        {
          name  = "WOODPECKER_SERVER"
          value = "server.${var.project_name}.local:9000"
        },
        {
          name  = "WOODPECKER_MIN_AGENTS"
          value = "0"
        },
        {
          name  = "WOODPECKER_MAX_AGENTS"
          value = tostring(var.agent_max_count)
        },
        {
          name  = "WOODPECKER_WORKFLOWS_PER_AGENT"
          value = tostring(var.agent_max_workflows)
        },
        {
          name  = "WOODPECKER_GRPC_SECURE"
          value = "false"
        },
        # AWS Provider Configuration
        {
          name  = "WOODPECKER_PROVIDER"
          value = "aws"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "WOODPECKER_AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "WOODPECKER_AWS_INSTANCE_TYPE"
          value = var.agent_instance_type
        },
        {
          name  = "WOODPECKER_AWS_IMAGE"
          value = data.aws_ami.amazon_linux_2023.id
        },
        {
          name  = "WOODPECKER_AWS_SUBNET_ID"
          value = aws_subnet.private[0].id
        },
        {
          name  = "WOODPECKER_AWS_SECURITY_GROUP"
          value = aws_security_group.agent_ec2.id
        },
        {
          name  = "WOODPECKER_AWS_IAM_PROFILE_ARN"
          value = aws_iam_instance_profile.agent.arn
        },
        {
          name  = "WOODPECKER_AWS_USER_DATA_BASE64"
          value = aws_launch_template.agent.user_data
        },
        {
          name  = "WOODPECKER_AWS_TAGS"
          value = "Name=${var.project_name}-agent,ManagedBy=woodpecker-autoscaler"
        }
      ]

      secrets = [
        {
          name      = "WOODPECKER_AGENT_SECRET"
          valueFrom = aws_secretsmanager_secret.woodpecker_agent_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.autoscaler.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "autoscaler"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-autoscaler"
  }
}

# -----------------------------------------------------------------------------
# Autoscaler ECS Service
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "autoscaler" {
  name            = "${var.project_name}-autoscaler"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.autoscaler.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  # Wait for server to be running
  depends_on = [aws_ecs_service.server]

  tags = {
    Name = "${var.project_name}-autoscaler"
  }
}

