# -----------------------------------------------------------------------------
# EFS File System for Woodpecker Data
# Using EFS with SQLite instead of RDS to save costs
# -----------------------------------------------------------------------------

resource "aws_efs_file_system" "woodpecker" {
  creation_token = "${var.project_name}-data"
  encrypted      = true

  # Use bursting throughput mode (free tier eligible, good for small workloads)
  throughput_mode = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.project_name}-data"
  }
}

# -----------------------------------------------------------------------------
# EFS Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-efs-sg"
  }
}

# -----------------------------------------------------------------------------
# EFS Mount Targets
# -----------------------------------------------------------------------------

resource "aws_efs_mount_target" "woodpecker" {
  count = length(var.availability_zones)

  file_system_id  = aws_efs_file_system.woodpecker.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# -----------------------------------------------------------------------------
# EFS Access Point for Woodpecker
# -----------------------------------------------------------------------------

resource "aws_efs_access_point" "woodpecker" {
  file_system_id = aws_efs_file_system.woodpecker.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/woodpecker"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.project_name}-access-point"
  }
}

