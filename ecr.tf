# -----------------------------------------------------------------------------
# ECR Repositories for Woodpecker Images
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "woodpecker_server" {
  name                 = "${var.project_name}-server"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-server"
  }
}

resource "aws_ecr_repository" "woodpecker_agent" {
  name                 = "${var.project_name}-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-agent"
  }
}

resource "aws_ecr_repository" "woodpecker_autoscaler" {
  name                 = "${var.project_name}-autoscaler"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-autoscaler"
  }
}

# -----------------------------------------------------------------------------
# ECR Lifecycle Policy (keep last 5 images)
# -----------------------------------------------------------------------------

resource "aws_ecr_lifecycle_policy" "woodpecker_server" {
  repository = aws_ecr_repository.woodpecker_server.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "woodpecker_agent" {
  repository = aws_ecr_repository.woodpecker_agent.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "woodpecker_autoscaler" {
  repository = aws_ecr_repository.woodpecker_autoscaler.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# -----------------------------------------------------------------------------
# Local values for image URIs
# -----------------------------------------------------------------------------

locals {
  server_image     = "${aws_ecr_repository.woodpecker_server.repository_url}:${var.woodpecker_version}"
  agent_image      = "${aws_ecr_repository.woodpecker_agent.repository_url}:${var.woodpecker_version}"
  autoscaler_image = "${aws_ecr_repository.woodpecker_autoscaler.repository_url}:latest"
}

# -----------------------------------------------------------------------------
# Push images to ECR (optional, requires docker/podman locally)
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "null_resource" "push_server_image" {
  count = var.push_images_to_ecr ? 1 : 0

  triggers = {
    version = var.woodpecker_version
    repo    = aws_ecr_repository.woodpecker_server.repository_url
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ${var.aws_region} | \
        ${var.container_runtime} login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      ${var.container_runtime} pull docker.io/woodpeckerci/woodpecker-server:${var.woodpecker_version}
      ${var.container_runtime} tag docker.io/woodpeckerci/woodpecker-server:${var.woodpecker_version} ${aws_ecr_repository.woodpecker_server.repository_url}:${var.woodpecker_version}
      ${var.container_runtime} push ${aws_ecr_repository.woodpecker_server.repository_url}:${var.woodpecker_version}
    EOF
  }

  depends_on = [aws_ecr_repository.woodpecker_server]
}

resource "null_resource" "push_agent_image" {
  count = var.push_images_to_ecr ? 1 : 0

  triggers = {
    version = var.woodpecker_version
    repo    = aws_ecr_repository.woodpecker_agent.repository_url
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ${var.aws_region} | \
        ${var.container_runtime} login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      ${var.container_runtime} pull docker.io/woodpeckerci/woodpecker-agent:${var.woodpecker_version}
      ${var.container_runtime} tag docker.io/woodpeckerci/woodpecker-agent:${var.woodpecker_version} ${aws_ecr_repository.woodpecker_agent.repository_url}:${var.woodpecker_version}
      ${var.container_runtime} push ${aws_ecr_repository.woodpecker_agent.repository_url}:${var.woodpecker_version}
    EOF
  }

  depends_on = [aws_ecr_repository.woodpecker_agent]
}

resource "null_resource" "push_autoscaler_image" {
  count = var.push_images_to_ecr ? 1 : 0

  triggers = {
    repo = aws_ecr_repository.woodpecker_autoscaler.repository_url
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ${var.aws_region} | \
        ${var.container_runtime} login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      ${var.container_runtime} pull docker.io/woodpeckerci/autoscaler:latest
      ${var.container_runtime} tag docker.io/woodpeckerci/autoscaler:latest ${aws_ecr_repository.woodpecker_autoscaler.repository_url}:latest
      ${var.container_runtime} push ${aws_ecr_repository.woodpecker_autoscaler.repository_url}:latest
    EOF
  }

  depends_on = [aws_ecr_repository.woodpecker_autoscaler]
}
