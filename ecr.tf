# -----------------------------------------------------------------------------
# ECR Repositories for Woodpecker Images
# Avoids Docker Hub rate limits
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "woodpecker_server" {
  count = var.use_ecr ? 1 : 0

  name                 = "${var.project_name}-server"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Allow destroying repo with images

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-server"
  }
}

resource "aws_ecr_repository" "woodpecker_agent" {
  count = var.use_ecr ? 1 : 0

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
  count = var.use_ecr ? 1 : 0

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
  count = var.use_ecr ? 1 : 0

  repository = aws_ecr_repository.woodpecker_server[0].name

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
  count = var.use_ecr ? 1 : 0

  repository = aws_ecr_repository.woodpecker_agent[0].name

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
  count = var.use_ecr ? 1 : 0

  repository = aws_ecr_repository.woodpecker_autoscaler[0].name

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
  # Use Docker Hub as primary source (ghcr.io has access issues)
  server_image = var.use_ecr ? "${aws_ecr_repository.woodpecker_server[0].repository_url}:${var.woodpecker_version}" : "docker.io/woodpeckerci/woodpecker-server:${var.woodpecker_version}"

  agent_image = var.use_ecr ? "${aws_ecr_repository.woodpecker_agent[0].repository_url}:${var.woodpecker_version}" : "docker.io/woodpeckerci/woodpecker-agent:${var.woodpecker_version}"

  autoscaler_image = var.use_ecr ? "${aws_ecr_repository.woodpecker_autoscaler[0].repository_url}:latest" : "docker.io/woodpeckerci/autoscaler:latest"
}

# -----------------------------------------------------------------------------
# Push images to ECR (optional, requires docker/podman locally)
# -----------------------------------------------------------------------------

# Data source to get AWS account ID for ECR login
data "aws_caller_identity" "current" {}

resource "null_resource" "push_server_image" {
  count = var.use_ecr && var.push_images_to_ecr ? 1 : 0

  triggers = {
    version = var.woodpecker_version
    repo    = aws_ecr_repository.woodpecker_server[0].repository_url
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ${var.aws_region} | \
        ${var.container_runtime} login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      ${var.container_runtime} pull docker.io/woodpeckerci/woodpecker-server:${var.woodpecker_version}
      ${var.container_runtime} tag docker.io/woodpeckerci/woodpecker-server:${var.woodpecker_version} ${aws_ecr_repository.woodpecker_server[0].repository_url}:${var.woodpecker_version}
      ${var.container_runtime} push ${aws_ecr_repository.woodpecker_server[0].repository_url}:${var.woodpecker_version}
    EOF
  }

  depends_on = [aws_ecr_repository.woodpecker_server]
}

resource "null_resource" "push_agent_image" {
  count = var.use_ecr && var.push_images_to_ecr ? 1 : 0

  triggers = {
    version = var.woodpecker_version
    repo    = aws_ecr_repository.woodpecker_agent[0].repository_url
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ${var.aws_region} | \
        ${var.container_runtime} login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      ${var.container_runtime} pull docker.io/woodpeckerci/woodpecker-agent:${var.woodpecker_version}
      ${var.container_runtime} tag docker.io/woodpeckerci/woodpecker-agent:${var.woodpecker_version} ${aws_ecr_repository.woodpecker_agent[0].repository_url}:${var.woodpecker_version}
      ${var.container_runtime} push ${aws_ecr_repository.woodpecker_agent[0].repository_url}:${var.woodpecker_version}
    EOF
  }

  depends_on = [aws_ecr_repository.woodpecker_agent]
}

resource "null_resource" "push_autoscaler_image" {
  count = var.use_ecr && var.push_images_to_ecr ? 1 : 0

  triggers = {
    repo = aws_ecr_repository.woodpecker_autoscaler[0].repository_url
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ${var.aws_region} | \
        ${var.container_runtime} login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      ${var.container_runtime} pull docker.io/woodpeckerci/autoscaler:latest
      ${var.container_runtime} tag docker.io/woodpeckerci/autoscaler:latest ${aws_ecr_repository.woodpecker_autoscaler[0].repository_url}:latest
      ${var.container_runtime} push ${aws_ecr_repository.woodpecker_autoscaler[0].repository_url}:latest
    EOF
  }

  depends_on = [aws_ecr_repository.woodpecker_autoscaler]
}

