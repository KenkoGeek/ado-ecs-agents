# Azure DevOps Agents on ECS Fargate

Serverless solution that runs Azure DevOps build agents on AWS ECS Fargate with automatic scaling based on Azure DevOps webhooks.

## Architecture

- **Zero cost** when no jobs are running
- **Automatic scaling** via Azure DevOps webhooks
- **One task per job** for complete isolation
- **(Optional) Public networking** to avoid NAT gateways costs

## Components

- **API Gateway + Lambda**: Processes Azure DevOps webhooks and manages ECS scaling
- **ECS Fargate**: Runs containerized Azure DevOps agents
- **ECR**: Stores the custom agent Docker image
- **VPC**: Isolated networking with public subnets

## Prerequisites

- A VPC with at least two subnets
- AWS CLI configured with appropriate permissions
- Docker installed for building the agent image
- Azure DevOps organization with admin access
- Personal Access Token (PAT) with Agent Pools (read, manage) permissions

## Quick Start

### 1. Build and Push Agent Image

```bash
# Build and push the Docker image to ECR
./build-image.sh
```

This will output an ECR URI like: `123456789012.dkr.ecr.us-east-1.amazonaws.com/azure-devops-agent:latest`

### 2. Deploy Infrastructure

```bash
# Deploy CloudFormation stack
./deploy-cf.sh
```

Or deploy manually with custom parameters:

```bash
aws cloudformation deploy \
  --template-file cloudformation.yaml \
  --stack-name azure-devops-ecs-agents \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    AzureDevOpsPAT="your-pat-token-here" \
    AzureDevOpsUrl="https://dev.azure.com/your-organization" \
    AgentPoolName="AWS-ECS-Pool" \
    VpcId="vpc-12345678" \
    SubnetIds="subnet-12345678,subnet-87654321" \
    ECRImageUri="123456789012.dkr.ecr.us-east-1.amazonaws.com/azure-devops-agent:latest"
```

### 3. Configure Azure DevOps Webhooks

After deployment, get the webhook URL and API key:

```bash
aws cloudformation describe-stacks \
  --stack-name azure-devops-ecs-agents \
  --query 'Stacks[0].Outputs'
```

Configure two webhooks in Azure DevOps:

#### Webhook 1 - Job Waiting (Scale Up)

- Go to **Project Settings** → **Service hooks**
- Create new webhook type **"Web Hooks"**
- **URL**: `{WebhookUrl}` (from CloudFormation output)
- **HTTP Headers**: `x-api-key: {ApiKey}` (from API Gateway console)
- **Trigger**: `Run Job state changed`
- **Pipeline**: `Any Pipeline`
- **State**: `Waiting`

#### Webhook 2 - Job Completed (Scale Down)

- Create second webhook type **"Web Hooks"**
- **URL**: `{WebhookUrl}` (same as above)
- **HTTP Headers**: `x-api-key: {ApiKey}` (same as above)
- **Trigger**: `Run state changed`
- **Pipeline**: `Any Pipeline`
- **State**: `Completed`

## Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `AzureDevOpsUrl` | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | Yes | - |
| `AzureDevOpsPAT` | Personal Access Token with Agent Pools permissions | Yes | - |
| `AgentPoolName` | Name of the agent pool in Azure DevOps | Yes | - |
| `VpcId` | Existing VPC ID where agents will run | Yes | - |
| `SubnetIds` | Comma-separated list of public subnet IDs | Yes | - |
| `ECRImageUri` | ECR URI of the built agent image | Yes | - |

## How It Works

1. **Job Queued** → Azure DevOps sends webhook → Lambda scales up ECS task
2. **Agent Starts** → Connects to Azure DevOps and picks up the job
3. **Job Executes** → Agent processes the pipeline
4. **Job Completes** → Azure DevOps sends webhook → Lambda stops the specific task

## Agent Image

The Docker image includes:

- Ubuntu 24.04 LTS base
- Azure DevOps agent (v4.258.1)
- AWS CLI v2
- Git, curl, wget, jq

### Customizing the Agent

Modify the `Dockerfile` to add additional tools:

```dockerfile
# Add your tools here
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*
```

Then rebuild and redeploy:

```bash
./build-image.sh
./deploy-cf.sh
```

## Monitoring

### CloudWatch Logs

- Agent logs: `/aws/ecs/azure-devops-agents`
- Lambda logs: `/aws/lambda/azure-devops-webhook-processor`
- API Gateway logs: `/aws/apigateway/{stack-name}-webhook`

### Viewing Running Tasks

```bash
aws ecs list-tasks --cluster azure-devops-cluster --desired-status RUNNING
```

### Debugging Webhooks

Check Lambda logs for webhook processing:

```bash
aws logs tail /aws/lambda/azure-devops-webhook-processor --follow
```

## Cost Optimization

- **Idle cost**: ~$0 (only API Gateway and Lambda at rest)
- **Active cost**: Fargate compute time only (~$0.05/hour per agent)
- **Cleanup**: Tasks automatically terminate after job completion

## Security

- Agents run in isolated Fargate tasks
- API Gateway protected with API keys
- IAM roles follow least privilege principle
- No persistent storage or state

## Troubleshooting

### Agent Not Connecting

1. Check CloudWatch logs for the ECS task
2. Verify PAT token has correct permissions
3. Ensure agent pool exists in Azure DevOps

### Webhook Not Triggering

1. Check API Gateway logs
2. Verify webhook URL and API key
3. Test webhook manually with curl

### Tasks Not Scaling Down

1. Check if webhook for "Completed" state is configured
2. Verify Lambda has ECS permissions
3. Check CloudWatch logs for errors

## Example Pipeline

```yaml
# azure-pipelines.yml
trigger:
- main

pool:
  name: 'AWS-ECS-Pool'

steps:
- script: |
    echo "Running on ECS Fargate agent"
    aws --version
  displayName: 'Test Agent Tools'
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with a sample pipeline
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
