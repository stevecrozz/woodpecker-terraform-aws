# -----------------------------------------------------------------------------
# Local Values for Server Configuration
# -----------------------------------------------------------------------------

locals {
  server_host     = var.domain_name != "" ? var.domain_name : aws_lb.main.dns_name
  server_protocol = var.acm_certificate_arn != "" ? "https" : "http"
  server_url      = "${local.server_protocol}://${local.server_host}"
}

# -----------------------------------------------------------------------------
# Service Discovery Namespace (for internal DNS)
# -----------------------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}.local"
  description = "Private DNS namespace for Woodpecker services"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "server" {
  name = "server"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# -----------------------------------------------------------------------------
# Woodpecker Server Task Definition
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "server" {
  family                   = "${var.project_name}-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.server_cpu
  memory                   = var.server_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "woodpecker-server"
      image     = local.server_image
      essential = true

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        },
        {
          containerPort = 9000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "WOODPECKER_HOST"
          value = local.server_url
        },
        {
          name  = "WOODPECKER_OPEN"
          value = "false"
        },
        {
          name  = "WOODPECKER_ADMIN"
          value = var.woodpecker_admin_users
        },
        {
          name  = "WOODPECKER_FORGE"
          value = var.woodpecker_forge_type
        },
        {
          name  = "WOODPECKER_GITHUB"
          value = var.woodpecker_forge_type == "github" ? "true" : "false"
        },
        {
          name  = "WOODPECKER_DATABASE_DRIVER"
          value = "sqlite3"
        },
        {
          name  = "WOODPECKER_DATABASE_DATASOURCE"
          value = "/var/lib/woodpecker/woodpecker.sqlite"
        },
        {
          name  = "WOODPECKER_LOG_LEVEL"
          value = "info"
        },
        {
          name  = "WOODPECKER_SERVER_ADDR"
          value = ":8000"
        },
        {
          name  = "WOODPECKER_GRPC_ADDR"
          value = ":9000"
        }
      ]

      secrets = [
        {
          name      = "WOODPECKER_AGENT_SECRET"
          valueFrom = aws_secretsmanager_secret.woodpecker_agent_secret.arn
        },
        {
          name      = "WOODPECKER_GITHUB_CLIENT"
          valueFrom = aws_secretsmanager_secret.woodpecker_github_client.arn
        },
        {
          name      = "WOODPECKER_GITHUB_SECRET"
          valueFrom = aws_secretsmanager_secret.woodpecker_github_secret.arn
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "woodpecker-data"
          containerPath = "/var/lib/woodpecker"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.server.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "server"
        }
      }

    }
  ])

  volume {
    name = "woodpecker-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.woodpecker.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.woodpecker.id
        iam             = "ENABLED"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-server"
  }
}

# -----------------------------------------------------------------------------
# Woodpecker Server ECS Service
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "server" {
  name            = "${var.project_name}-server"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.server.arn
    container_name   = "woodpecker-server"
    container_port   = 8000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.server.arn
  }

  # Ensure EFS mount targets are ready before starting the service
  depends_on = [
    aws_efs_mount_target.woodpecker,
    aws_lb_listener.http
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name = "${var.project_name}-server"
  }
}

