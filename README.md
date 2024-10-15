# Portfolio Terraform AWS Project

This project deploys a fully functional ECS Fargate service running NGINX, using a VPC with public and private subnets. The NGINX service is placed in private subnets behind an Application Load Balancer (ALB) for routing traffic, and the infrastructure is managed using Terraform.

## Prerequisites

- Terraform installed (version >= 1.0.0)
- AWS account and credentials configured (via `aws configure` or environment variables)
- IAM permissions to create VPCs, ECS clusters, ALBs, security groups, and other AWS resources

## Project Structure

This project is split into two Terraform files for easier management:

1. **vpc.tf**: Contains the configuration for setting up the VPC, subnets (public and private), Internet Gateway, NAT Gateway, and route tables.
2. **nginx-ecs-fargate.tf**: Contains the ECS cluster, task definition, security groups, Fargate service, and Application Load Balancer configuration.

### Key Components

- **VPC**: The VPC is configured with both public and private subnets.
  - **Public Subnets**: These host the Application Load Balancer (ALB) and NAT Gateway.
  - **Private Subnets**: These host the ECS tasks for the NGINX service.
  
- **ECS Fargate**: The NGINX service runs on ECS Fargate, which is serverless and managed by AWS.
  - **Task Definition**: Specifies the NGINX Docker image, resource requirements (CPU/memory), and logging to CloudWatch.
  - **Security Groups**: Control access to the ECS tasks and ALB.
  
- **Application Load Balancer (ALB)**: Routes external traffic to the NGINX service running in the private subnets.

## How to Deploy

### Step 1: Initialize Terraform

Run the following command to initialize the Terraform environment:

```bash
terraform init
```

### Step 2: Create a Plan
Create a plan to review the resources that Terraform will create:
```bash
terraform plan
```
Ensure there are no issues or errors in the plan output.

### Step 3: Apply the Configuration
To deploy the infrastructure, run:
```bash
terraform apply
```
Type yes when prompted to confirm the apply.

### Step 4: Retrieve the Load Balancer DNS
After the apply finishes, you can retrieve the DNS of the Application Load Balancer to access the NGINX service:
```bash
terraform output nginx_lb_dns
```
Navigate to the provided DNS in your browser to verify that NGINX is running.

## File Breakdown

### `vpc.tf`

- **VPC and Subnets**: Defines a VPC with 3 public and 3 private subnets across different availability zones.
- **Internet Gateway and NAT Gateway**: Provides internet access to the public subnets and routes traffic from the private subnets through the NAT Gateway.
- **Route Tables**: Configures routing for public and private subnets.
- **Outputs**: Outputs the VPC ID, public and private subnet IDs, and other key values.

### `nginx-ecs-fargate.tf`

- **ECS Cluster**: Defines the ECS cluster where the Fargate service is deployed.
- **Task Definition**: Configures the NGINX container and links to CloudWatch logs for monitoring.
- **ALB and Listener**: Sets up an Application Load Balancer with a listener on port 80 to forward traffic to the NGINX service.
- **Security Groups**: Configures security rules to allow traffic between the ALB and ECS tasks.
- **Outputs**: Outputs the DNS name of the ALB.

## How to Destroy the Infrastructure

To remove all the resources created by Terraform, run:

```bash
terraform destroy
```
Type yes to confirm the destroy action.

## Notes

- Ensure that your AWS credentials have the necessary permissions to create the required resources.
- The logs for the NGINX service can be viewed in CloudWatch under the log group `/ecs/nginx`.

## Future Improvements

- Add autoscaling for the ECS service based on CPU or memory utilization.
- Implement HTTPS with SSL termination on the Application Load Balancer.
- Move state to S3 / DynamoDB
