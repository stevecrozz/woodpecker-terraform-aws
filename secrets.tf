# -----------------------------------------------------------------------------
# Random Secret for Agent Authentication
# -----------------------------------------------------------------------------

resource "random_password" "agent_secret" {
  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# Secrets Manager Secrets
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "woodpecker_agent_secret" {
  name                    = "${var.project_name}/agent-secret"
  description             = "Shared secret for Woodpecker agent authentication"
  recovery_window_in_days = 0 # Immediate deletion for cost savings in dev

  tags = {
    Name = "${var.project_name}-agent-secret"
  }
}

resource "aws_secretsmanager_secret_version" "woodpecker_agent_secret" {
  secret_id     = aws_secretsmanager_secret.woodpecker_agent_secret.id
  secret_string = random_password.agent_secret.result
}

# GitHub OAuth Credentials
resource "aws_secretsmanager_secret" "woodpecker_github_client" {
  name                    = "${var.project_name}/github-client-id"
  description             = "GitHub OAuth Client ID for Woodpecker"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-github-client-id"
  }
}

resource "aws_secretsmanager_secret_version" "woodpecker_github_client" {
  secret_id     = aws_secretsmanager_secret.woodpecker_github_client.id
  secret_string = var.woodpecker_github_client_id != "" ? var.woodpecker_github_client_id : "placeholder"
}

resource "aws_secretsmanager_secret" "woodpecker_github_secret" {
  name                    = "${var.project_name}/github-client-secret"
  description             = "GitHub OAuth Client Secret for Woodpecker"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-github-client-secret"
  }
}

resource "aws_secretsmanager_secret_version" "woodpecker_github_secret" {
  secret_id     = aws_secretsmanager_secret.woodpecker_github_secret.id
  secret_string = var.woodpecker_github_client_secret != "" ? var.woodpecker_github_client_secret : "placeholder"
}

