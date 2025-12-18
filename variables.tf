# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "woodpecker"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

# -----------------------------------------------------------------------------
# Domain & SSL
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Domain name for Woodpecker CI (e.g., ci.example.com). Leave empty to use ALB DNS."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS. Required if domain_name is set."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Woodpecker Configuration
# -----------------------------------------------------------------------------

variable "woodpecker_version" {
  description = "Woodpecker CI version tag"
  type        = string
  default     = "v2.8.3"
}

variable "woodpecker_admin_users" {
  description = "Comma-separated list of admin usernames"
  type        = string
  default     = ""
}

variable "woodpecker_forge_type" {
  description = "Git forge type (github, gitlab, gitea, bitbucket, forgejo)"
  type        = string
  default     = "github"
}

variable "woodpecker_forge_url" {
  description = "URL of the git forge (only needed for self-hosted forges)"
  type        = string
  default     = ""
}

variable "woodpecker_github_client_id" {
  description = "GitHub OAuth App Client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "woodpecker_github_client_secret" {
  description = "GitHub OAuth App Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# ECS Server Configuration
# -----------------------------------------------------------------------------

variable "server_cpu" {
  description = "CPU units for server task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "server_memory" {
  description = "Memory for server task in MB"
  type        = number
  default     = 512
}

# -----------------------------------------------------------------------------
# EC2 Agent Configuration (managed by Woodpecker Autoscaler)
# -----------------------------------------------------------------------------

variable "agent_instance_type" {
  description = "EC2 instance type for agent instances"
  type        = string
  default     = "t3.small"
}

variable "agent_max_count" {
  description = "Maximum number of agent instances"
  type        = number
  default     = 5
}

variable "agent_max_workflows" {
  description = "Maximum concurrent workflows per agent"
  type        = number
  default     = 2
}

