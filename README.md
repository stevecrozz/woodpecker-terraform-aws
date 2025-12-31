# Woodpecker CI on AWS ECS

A cost-optimized deployment of [Woodpecker CI](https://woodpecker-ci.org/) on AWS using Terraform. This setup uses **Woodpecker's built-in autoscaler** to manage EC2 agent instances, scaling to zero when idle.

## ⚠️ Project Status

**Alpha / Proof of Concept** - This has been deployed successfully once. Use at your own risk.

**Not production-ready:**
- No HTTPS configured (HTTP only via ALB DNS)
- Single NAT Gateway (not HA - if it fails, agents lose internet)
- SQLite on EFS (works, but PostgreSQL recommended for high concurrency)
- No automated EFS backups
- Secrets stored in Terraform state (use remote state with encryption)
- No CloudWatch alarms or alerting
- 7-day log retention (may be too short for production debugging)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                    VPC                                      │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         Public Subnets                                 │ │
│  │   ┌─────────────┐                                                      │ │
│  │   │     ALB     │◄──────── Internet Traffic                            │ │
│  │   └──────┬──────┘                                                      │ │
│  └──────────┼─────────────────────────────────────────────────────────────┘ │
│             │                                                               │
│  ┌──────────┼─────────────────────────────────────────────────────────────┐ │
│  │          │              Private Subnets                                │ │
│  │          ▼                                                             │ │
│  │   ┌─────────────┐         ┌─────────────┐        ┌─────────────┐       │ │
│  │   │  Woodpecker │ gRPC    │  Woodpecker │ manages│    EC2      │       │ │
│  │   │   Server    │◄───────►│  Autoscaler │───────►│   Agents    │       │ │
│  │   │  (Fargate)  │         │  (Fargate)  │        │  (0 to N)   │       │ │
│  │   └──────┬──────┘         └─────────────┘        └─────────────┘       │ │
│  │          │                                                             │ │
│  │          ▼                                                             │ │
│  │   ┌─────────────┐                                                      │ │
│  │   │     EFS     │  SQLite Database + Data                              │ │
│  │   └─────────────┘                                                      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## How Autoscaling Works

The **Woodpecker Autoscaler** is Woodpecker's official solution for managing agent capacity:

1. **Monitors queue depth** - Connects to the server and watches for pending jobs
2. **Scales up** - When jobs are queued, spins up EC2 instances running agents
3. **Scales down** - When agents are idle, terminates instances
4. **Scale to zero** - No agents running when there's no work (minimum cost)

This is event-driven at the application level - the autoscaler reacts to Woodpecker's internal queue state, not external metrics.

## Container Images

Container images are stored in **ECR** (Elastic Container Registry) to avoid Docker Hub rate limits. During `terraform apply`, images are automatically pulled from Docker Hub and pushed to your ECR repositories (requires Docker or Podman locally).

## Cost Optimization Features

| Feature | Savings |
|---------|---------|
| **Scale to Zero** | No agent costs when idle |
| **SQLite on EFS** | No RDS costs (~$15-30/month saved) |
| **Single NAT Gateway** | ~$30/month saved vs multi-AZ NAT |
| **Minimal Server Resources** | 0.25 vCPU, 512MB RAM |
| **7-Day Log Retention** | Reduced CloudWatch costs |

### Estimated Monthly Costs

| Component | Cost (idle) | Cost (active) |
|-----------|-------------|---------------|
| ALB | ~$16 | ~$16 |
| NAT Gateway | ~$32 | ~$32 + data |
| Server (Fargate) | ~$9 | ~$9 |
| Autoscaler (Fargate) | ~$9 | ~$9 |
| Agents (EC2 t3.small) | $0 | ~$0.02/hour per agent |
| EFS | ~$0.30/GB | ~$0.30/GB |
| **Total (idle)** | **~$66/month** | |

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5.0
3. Docker or Podman (for pushing images to ECR)
4. A GitHub OAuth App (or other forge credentials)

### Creating a GitHub OAuth App

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click "New OAuth App"
3. Fill in:
   - **Application name**: Woodpecker CI
   - **Homepage URL**: Your Woodpecker URL (ALB DNS or custom domain)
   - **Authorization callback URL**: `http://your-alb-dns/authorize` (update after deploy)
4. Save the Client ID and Client Secret

> **Note**: You can use HTTP with the ALB DNS name for testing. For production, set up a custom domain with HTTPS.

## Quick Start

1. **Clone and configure:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Initialize and deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Get the URL and update GitHub OAuth:**
   ```bash
   terraform output woodpecker_url
   ```
   Update your GitHub OAuth App's callback URL to `<woodpecker_url>/authorize`

4. **Create API token for autoscaler:**
   - Log into Woodpecker at the URL from step 3
   - Go to User Settings → Personal Access Tokens
   - Create a token and add it to `terraform.tfvars` as `woodpecker_api_token`
   - Run `terraform apply` again to update the autoscaler

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `woodpecker_github_client_id` | GitHub OAuth Client ID |
| `woodpecker_github_client_secret` | GitHub OAuth Client Secret |
| `woodpecker_admin_users` | Comma-separated list of admin usernames |
| `woodpecker_api_token` | API token for autoscaler (create after first deploy) |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-west-2` | AWS region |
| `domain_name` | `""` | Custom domain (uses ALB DNS if empty) |
| `acm_certificate_arn` | `""` | ACM certificate for HTTPS |
| `woodpecker_version` | see variables.tf | Woodpecker version tag |
| `server_cpu` | `256` | Server CPU units (256 = 0.25 vCPU) |
| `server_memory` | `512` | Server memory in MB |
| `agent_instance_type` | `t3.small` | EC2 instance type for agents |
| `agent_max_count` | `5` | Maximum concurrent agent instances |
| `agent_max_workflows` | `2` | Concurrent workflows per agent |
| `push_images_to_ecr` | `true` | Auto-push images from Docker Hub to ECR |
| `container_runtime` | `podman` | Container runtime for pushing images |

## Custom Domain Setup

1. Create an ACM certificate in the same region:
   ```bash
   aws acm request-certificate \
     --domain-name ci.example.com \
     --validation-method DNS
   ```

2. Validate the certificate via DNS

3. Add to `terraform.tfvars`:
   ```hcl
   domain_name = "ci.example.com"
   acm_certificate_arn = "arn:aws:acm:us-west-2:123456789:certificate/xxx"
   ```

4. Create a Route53 alias record pointing to the ALB

## Monitoring

### View Logs

```bash
# Server logs
aws logs tail /ecs/woodpecker/server --follow

# Autoscaler logs
aws logs tail /ecs/woodpecker/autoscaler --follow
```

Agent logs are on the EC2 instances themselves (use `docker logs woodpecker-agent` via SSH or Session Manager).

### Check Running Agents

```bash
# List agent EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=woodpecker-autoscaler" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,Type:InstanceType}' \
  --output table
```

### Check ECS Services

```bash
aws ecs describe-services \
  --cluster woodpecker-cluster \
  --services woodpecker-server woodpecker-autoscaler \
  --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount}'
```

## Troubleshooting

### Server won't start

1. Check EFS mount targets are ready in both AZs
2. Verify secrets are populated in Secrets Manager
3. Check CloudWatch logs for errors

### Autoscaler not creating agents

1. Check autoscaler logs for errors
2. Verify IAM permissions allow EC2 operations
3. Ensure subnet has NAT gateway access
4. Check security group allows outbound traffic

### Agents won't connect to server

1. Verify the server is healthy (`/healthz` endpoint)
2. Check security group allows gRPC traffic (port 9000)
3. Verify agent secret matches server secret
4. Check Service Discovery DNS is resolving

### GitHub OAuth errors

1. Verify callback URL matches exactly
2. Check client ID and secret are correct
3. Ensure WOODPECKER_HOST matches the actual URL

### Image pull errors on agents

1. Check agent instance has IAM role with ECR permissions
2. Verify ECR login step runs in user data script
3. Check EC2 console output: `aws ec2 get-console-output --instance-id <id>`

## Cleanup

```bash
# First, ensure autoscaler has terminated all agents
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=woodpecker-autoscaler" "Name=instance-state-name,Values=running"

# Then destroy infrastructure
terraform destroy
```

**Note**: EFS data and ECR images will be deleted. Back up important data before destroying.

## Security Considerations

- Secrets are stored in AWS Secrets Manager
- EFS is encrypted at rest
- All traffic to server is through ALB
- Agents run in private subnets with NAT egress only
- EC2 agents use IAM instance profiles (no hardcoded credentials)

## Contributing

Feel free to submit issues and pull requests!

## License

MIT
