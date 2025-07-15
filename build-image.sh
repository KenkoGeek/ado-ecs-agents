#!/bin/bash

# Build and push Docker image to ECR

REGION=${AWS_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_NAME="azure-devops-agent"
IMAGE_TAG="latest"

ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"

echo "Building Docker image..."
docker build -t ${REPO_NAME}:${IMAGE_TAG} .

echo "Creating ECR repository if it doesn't exist..."
aws ecr describe-repositories --repository-names ${REPO_NAME} --region ${REGION} 2>/dev/null || \
aws ecr create-repository --repository-name ${REPO_NAME} --region ${REGION}

echo "Logging into ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_URI}

echo "Tagging image..."
docker tag ${REPO_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}

echo "Pushing image to ECR..."
docker push ${ECR_URI}:${IMAGE_TAG}

echo "Image pushed successfully!"
echo "ECR URI: ${ECR_URI}:${IMAGE_TAG}"
echo ""
echo "Use this URI as ECRImageUri parameter when deploying template"