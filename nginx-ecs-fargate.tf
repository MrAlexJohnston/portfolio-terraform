# ECS Cluster
resource "aws_ecs_cluster" "nginx_cluster" {
  name = "nginx-cluster"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsNginxTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
}

# ECS Task Definition for NGINX
resource "aws_ecs_task_definition" "nginx_task" {
  family                   = "nginx-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "nginx"
    image     = "nginx:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.nginx_log_group.name
        "awslogs-region"        = "eu-west-2"
        "awslogs-stream-prefix" = "nginx"
      }
    }
  }])
}

# Security Group for ECS NGINX Fargate Service
resource "aws_security_group" "nginx_sg" {
  vpc_id = aws_vpc.terraform_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-security-group"
  }
}

# Application Load Balancer for NGINX ECS Fargate Service
resource "aws_lb" "nginx_lb" {
  name               = "nginx-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nginx_sg.id]
  subnets            = aws_subnet.public_subnet[*].id
}

# Listener for Application Load Balancer
resource "aws_lb_listener" "nginx_lb_listener" {
  load_balancer_arn = aws_lb.nginx_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }
}

# Target Group for NGINX ECS Fargate Service
resource "aws_lb_target_group" "nginx_tg" {
  name     = "nginx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_cloudwatch_log_group" "nginx_log_group" {
  name              = "/ecs/nginx"
  retention_in_days = 7
}

# ECS Fargate Service for NGINX
resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.nginx_cluster.id
  task_definition = aws_ecs_task_definition.nginx_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private_subnet[*].id
    security_groups  = [aws_security_group.nginx_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx_tg.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.nginx_lb_listener]
}

# Outputs for Load Balancer DNS
output "nginx_lb_dns" {
  value       = aws_lb.nginx_lb.dns_name
  description = "DNS name of the NGINX load balancer"
}
