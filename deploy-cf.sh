#!/bin/bash

# Deploy CloudFormation stack for Azure DevOps ECS Agents

STACK_NAME="azure-devops-ecs-agents"
TEMPLATE_FILE="cloudformation.yaml"
AWS_DEFAULT_REGION="us-east-1"

echo "Deploying CloudFormation stack: $STACK_NAME"

aws cloudformation deploy \
  --template-file $TEMPLATE_FILE \
  --stack-name $STACK_NAME \
  --capabilities CAPABILITY_IAM \
  --region $AWS_DEFAULT_REGION
  --parameter-overrides \
    AzureDevOpsPAT="your-pat-token-here" \
    AzureDevOpsUrl="https://dev.azure.com/<your-organization>" \
    AgentPoolName="AWS-ECS-Node-Pool" \
    VpcId="vpc-12345678" \
    SubnetIds="subnet-12345678,subnet-87654321" \
    ECRImageUri="<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/<REPO_NAME>:latest"

echo "Deployment complete!"
echo ""
echo "Get outputs:"
echo "aws cloudformation describe-stacks --region $AWS_DEFAULT_REGION --stack-name $STACK_NAME --query 'Stacks[0].Outputs'"