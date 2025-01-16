provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  prefix = "${var.app_name}"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.prefix}-vpc"
    Environment = var.environment
  }
}
# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.prefix}-igw"
    Environment = var.environment
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${local.prefix}-public-rt"
    Environment = var.environment
  }
}

# Associate Public Subnets with Route Table
resource "aws_route_table_association" "public_subnets" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# Public Subnets
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.prefix}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${local.prefix}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Security Group for ECS
resource "aws_security_group" "ecs_tasks" {
  name   = "${local.prefix}-ecs-tasks-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
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
    Name        = "${local.prefix}-ecs-tasks-sg"
    Environment = var.environment
  }
}

# alb and target group
resource "aws_lb" "main" {
  name               = "${local.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_tasks.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name        = "${local.prefix}-alb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.prefix}-target-group"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

#   health_check {
#     path                = "/api/tasks"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 3
#     unhealthy_threshold = 3
#   }


  tags = {
    Name        = "${local.prefix}-target-group"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.prefix}-ecs-task-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECR Repository
resource "aws_ecr_repository" "main" {
  name = "${local.prefix}-repo"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${local.prefix}-ecr"
    Environment = var.environment
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name        = "${local.prefix}-cluster"
    Environment = var.environment
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = var.app_name
      image = "${aws_ecr_repository.main.repository_url}:latest"
      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.main.endpoint
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "DB_PORT"
          value = tostring(aws_db_instance.main.port)
        },
        {
          name  = "DB_URL"
          value = "jdbc:postgresql://${aws_db_instance.main.endpoint}:5432/${var.db_name}"
        },
        {
          name  = "DB_PLATFORM"
          value = var.db_platform
        }
      ],
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret_version.db_password.arn
        }
      ]
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${local.prefix}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${local.prefix}-task-definition"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${local.prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  depends_on = [aws_lb_listener.main]

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  tags = {
    Name        = "${local.prefix}-service"
    Environment = var.environment
  }
}

# RDS

resource "aws_security_group" "rds" {
  name   = "${local.prefix}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = {
    Name        = "${local.prefix}-rds-sg"
    Environment = var.environment
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${local.prefix}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier        = "${local.prefix}-db"
  engine            = "postgres"
  engine_version    = "14"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true

  performance_insights_enabled = true

  backup_retention_period = 7

  storage_encrypted = true

  tags = {
    Name        = "${local.prefix}-rds"
    Environment = var.environment
  }
}

# AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "${local.prefix}-db-pass-123"

  tags = {
    Name        = "${local.prefix}-db-password"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}