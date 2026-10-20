# Multi-Cloud Infrastructure as Code (AWS & Azure)
# Provisions production resources for simultaneous multi-cloud continuous deployment

# Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Generate unique suffix for globally unique cloud names (e.g., Azure ACR, WebApp)
resource "random_string" "resource_suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  # Azure Container Registry permits only alphanumeric characters
  acr_clean_name = substr(
    "acr${replace(replace(var.project_name, "-", ""), "_", "")}${random_string.resource_suffix.result}",
    0,
    50
  )
}

# AWS Infrastructure (Amazon ECR, App Runner & ECS Fargate Skeleton)

# 1. Amazon Elastic Container Registry (ECR)
resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.project_name}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# 2. ECR Lifecycle Policy (Auto-purge stale artifacts to remain in Free Tier)
resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain maximum 10 latest deployment images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-", "latest", "prod"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# 3. AWS App Runner ECR Access IAM Role
resource "aws_iam_role" "apprunner_ecr_access" {
  name = "${var.project_name}-apprunner-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_attachment" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# 4. AWS App Runner Service (Fully Managed Containerized Deployment)
resource "aws_apprunner_service" "app_service" {
  service_name = "${var.project_name}-svc"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    image_repository {
      image_identifier      = "${aws_ecr_repository.app_repo.repository_url}:${var.image_tag}"
      image_repository_type = "ECR"

      image_configuration {
        port = tostring(var.container_port)
        runtime_environment_variables = {
          CLOUD_PROVIDER = "AWS"
          REGION         = var.aws_region
          APP_VERSION    = "1.0.0"
        }
      }
    }

    auto_deployments_enabled = true
  }

  instance_configuration {
    cpu    = var.app_runner_cpu
    memory = var.app_runner_memory
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-apprunner"
  }

  depends_on = [aws_iam_role_policy_attachment.apprunner_ecr_attachment]
}

# 5. ECS Fargate Cluster & Task Definition Skeleton
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${var.project_name}-ecs-cluster"
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

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
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.app_repo.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "CLOUD_PROVIDER", value = "AWS" },
        { name = "REGION", value = var.aws_region },
        { name = "PORT", value = tostring(var.container_port) }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# Microsoft Azure Infrastructure (Resource Group, ACR & Linux Web App)

# 1. Azure Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.azure_location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# 2. Azure Container Registry (Basic SKU, Admin Enabled)
resource "azurerm_container_registry" "acr" {
  name                = local.acr_clean_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# 3. Azure Linux App Service Plan (Free F1 Tier)
resource "azurerm_service_plan" "asp" {
  name                = "asp-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# 4. Azure Linux Web App for Containers
resource "azurerm_linux_web_app" "app" {
  name                = "app-${var.project_name}-${random_string.resource_suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    always_on = false # Mandatory constraint: F1 Free SKU does not permit always_on = true

    application_stack {
      docker_image_name        = "${azurerm_container_registry.acr.login_server}/${var.project_name}:${var.image_tag}"
      docker_registry_url      = "https://${azurerm_container_registry.acr.login_server}"
      docker_registry_username = azurerm_container_registry.acr.admin_username
      docker_registry_password = azurerm_container_registry.acr.admin_password
    }
  }

  app_settings = {
    WEBSITES_PORT                       = tostring(var.container_port)
    CLOUD_PROVIDER                      = "Azure"
    REGION                              = var.azure_location
    APP_VERSION                         = "1.0.0"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  depends_on = [azurerm_container_registry.acr]
}
