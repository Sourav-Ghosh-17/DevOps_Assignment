#!/bin/bash

# Exit on error
set -e

# Variables
ALB_NAME="your-load-balancer-name"   # Replace with your ALB/ELB name
WEB_APP_AMI_ID="ami-xxxxxxxxxxxxxxx" # Replace with your AMI ID for new EC2 instances
INSTANCE_TYPE="t2.micro"             # Instance type for new web-app instances
SECURITY_GROUP="sg-xxxxxxxxxxxxxxx"  # Security Group ID
SUBNET_ID="subnet-xxxxxxxxxxxxxxx"   # Subnet ID
ELB_TARGET_GROUP="your-target-group" # Target Group for Load Balancer

MONGO_INSTANCE_ID="i-xxxxxxxxxxxxxxx"  # MongoDB EC2 Instance ID
ES_DOMAIN="your-es-domain"            # Elasticsearch Domain Name

# Function to get ALB Request Count
get_alb_request_count() {
    METRIC_VALUE=$(aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB \
        --metric-name RequestCount --dimensions Name=LoadBalancer,Value=$ALB_NAME \
        --statistics Sum --period 300 --start-time $(date -u -d '-5 minutes' +%Y-%m-%dT%H:%M:%SZ) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) --region us-east-1 | jq -r '.Datapoints[0].Sum')

    echo "${METRIC_VALUE:-0}"
}

# Function to launch a new Web-App EC2 instance
scale_up_web_app() {
    echo "Scaling up Web-App EC2 Instance..."
    INSTANCE_ID=$(aws ec2 run-instances --image-id $WEB_APP_AMI_ID --instance-type $INSTANCE_TYPE \
        --security-group-ids $SECURITY_GROUP --subnet-id $SUBNET_ID --count 1 \
        --query 'Instances[0].InstanceId' --output text)
    
    echo "New Web-App instance launched: $INSTANCE_ID"

    # Register the new instance to Target Group
    aws elbv2 register-targets --target-group-arn $ELB_TARGET_GROUP --targets Id=$INSTANCE_ID
    echo "Instance added to Load Balancer Target Group."
}

# Function to increase Elasticsearch Nodes
increase_es_nodes() {
    echo "Increasing Elasticsearch Nodes..."
    CURRENT_INSTANCE_COUNT=$(aws opensearch describe-domain --domain-name $ES_DOMAIN --query 'DomainStatus.ClusterConfig.InstanceCount' --output text)
    NEW_INSTANCE_COUNT=$((CURRENT_INSTANCE_COUNT + 1))

    aws opensearch update-domain-config --domain-name $ES_DOMAIN --cluster-config InstanceCount=$NEW_INSTANCE_COUNT
    echo "Elasticsearch node count updated to $NEW_INSTANCE_COUNT."
}

# Function to resize MongoDB EC2 instance
resize_mongo_instance() {
    echo "Changing MongoDB instance type..."
    aws ec2 stop-instances --instance-ids $MONGO_INSTANCE_ID
    echo "Waiting for MongoDB instance to stop..."
    aws ec2 wait instance-stopped --instance-ids $MONGO_INSTANCE_ID

    aws ec2 modify-instance-attribute --instance-id $MONGO_INSTANCE_ID --instance-type "{\"Value\": \"m4.xlarge\"}"
    echo "MongoDB instance type updated to m4.xlarge."

    aws ec2 start-instances --instance-ids $MONGO_INSTANCE_ID
    echo "MongoDB instance restarted."
}

# Main Execution Logic
REQUEST_COUNT=$(get_alb_request_count)
echo "Current ALB Request Count: $REQUEST_COUNT"

if [[ $REQUEST_COUNT -gt 1000 ]]; then
    scale_up_web_app
    increase_es_nodes
    resize_mongo_instance
else
    echo "No scaling required. Request count is below threshold."
fi
