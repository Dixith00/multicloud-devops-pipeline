# Terraform Input Variables Definition
# Configurable multi-cloud infrastructure parameters with free-tier defaults

variable "aws_region" {
  type        = string
  description = "AWS deployment region (ap-south-1 Mumbai has low latency and free-tier compatibility)"
  default     = "ap-south-1"
}

variable "azure_location" {
  type        = string
  description = "Azure deployment location (Central India region supports Free F1 App Service plans)"
  default     = "Central India"
}

variable "project_name" {
  type        = string
  description = "Project name identifier used for prefixing cloud resources across AWS and Azure"
  default     = "multicloud-devops-pipeline"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Deployment lifecycle stage (e.g., dev, staging, prod)"
  default     = "prod"
}

variable "container_port" {
  type        = number
  description = "Network port exposed by the application container"
  default     = 8080
}

variable "image_tag" {
  type        = string
  description = "Default container image tag deployed across cloud providers"
  default     = "latest"
}

variable "app_runner_cpu" {
  type        = string
  description = "CPU configuration for AWS App Runner service (1024 = 1 vCPU)"
  default     = "1024"
}

variable "app_runner_memory" {
  type        = string
  description = "Memory configuration for AWS App Runner service (2048 = 2 GB RAM)"
  default     = "2048"
}
