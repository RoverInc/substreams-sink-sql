# Environment variables
aws_region := env('AWS_REGION', 'us-east-1')
aws_profile := env('AWS_PROFILE', 'default')
ecr_repo := "substreams-sink-sql"

# Build and push Docker image to ECR
[group('docker')]
push-image:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔹 Building and pushing Docker image to ECR..."

    # Resolve AWS account ID
    aws_account_id=$(aws sts get-caller-identity \
        --profile {{aws_profile}} \
        --region {{aws_region}} \
        --query Account --output text)

    # ECR registry URL
    ecr_url="${aws_account_id}.dkr.ecr.{{aws_region}}.amazonaws.com"

    echo "Using AWS Account: $aws_account_id"
    echo "Using Repository: {{ecr_repo}}"
    echo "Using Region: {{aws_region}}"

    # Authenticate Docker with ECR
    aws ecr get-login-password \
        --profile {{aws_profile}} \
        --region {{aws_region}} \
        | docker login --username AWS --password-stdin "$ecr_url"

    # Ensure ECR repo exists
    if ! aws ecr describe-repositories \
        --profile {{aws_profile}} \
        --region {{aws_region}} \
        --repository-names {{ecr_repo}} >/dev/null 2>&1; then
        echo "ECR repo '{{ecr_repo}}' not found, creating..."
        aws ecr create-repository \
            --profile {{aws_profile}} \
            --region {{aws_region}} \
            --repository-name {{ecr_repo}}
    fi

    # Build Docker image
    docker build -t {{ecr_repo}}:latest .

    # Tag image for ECR
    docker tag {{ecr_repo}}:latest "$ecr_url/{{ecr_repo}}:latest"

    # Push image to ECR
    docker push "$ecr_url/{{ecr_repo}}:latest"

    echo "✅ Successfully pushed image to $ecr_url/{{ecr_repo}}:latest"
