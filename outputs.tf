# -----------------------------------------------------------------------------
# Networking Outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# -----------------------------------------------------------------------------
# Load Balancer Outputs
# -----------------------------------------------------------------------------

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer (for Route53 alias records)"
  value       = aws_lb.main.zone_id
}

output "woodpecker_url" {
  description = "URL to access Woodpecker CI"
  value       = local.server_url
}

# -----------------------------------------------------------------------------
# ECS Outputs
# -----------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "server_service_name" {
  description = "Name of the Woodpecker server ECS service"
  value       = aws_ecs_service.server.name
}

output "autoscaler_service_name" {
  description = "Name of the Woodpecker autoscaler ECS service"
  value       = aws_ecs_service.autoscaler.name
}


# -----------------------------------------------------------------------------
# Storage Outputs
# -----------------------------------------------------------------------------

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.woodpecker.id
}

# -----------------------------------------------------------------------------
# Secrets Outputs
# -----------------------------------------------------------------------------

output "agent_secret_arn" {
  description = "ARN of the agent secret in Secrets Manager"
  value       = aws_secretsmanager_secret.woodpecker_agent_secret.arn
}

# -----------------------------------------------------------------------------
# CloudWatch Outputs
# -----------------------------------------------------------------------------

output "server_log_group" {
  description = "CloudWatch log group for server logs"
  value       = aws_cloudwatch_log_group.server.name
}

output "agent_log_group" {
  description = "CloudWatch log group for agent logs"
  value       = aws_cloudwatch_log_group.agent.name
}

# -----------------------------------------------------------------------------
# Service Discovery Outputs
# -----------------------------------------------------------------------------

output "service_discovery_namespace" {
  description = "Service discovery namespace for internal DNS"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "server_internal_dns" {
  description = "Internal DNS name for the Woodpecker server"
  value       = "server.${aws_service_discovery_private_dns_namespace.main.name}"
}

# -----------------------------------------------------------------------------
# ECR Outputs
# -----------------------------------------------------------------------------

output "ecr_server_repository" {
  description = "ECR repository URL for server image"
  value       = aws_ecr_repository.woodpecker_server.repository_url
}

output "ecr_agent_repository" {
  description = "ECR repository URL for agent image"
  value       = aws_ecr_repository.woodpecker_agent.repository_url
}

output "ecr_autoscaler_repository" {
  description = "ECR repository URL for autoscaler image"
  value       = aws_ecr_repository.woodpecker_autoscaler.repository_url
}

