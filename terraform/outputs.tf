# Terraform Outputs Definition
# Exposes connection strings, container registry URIs, and live public URLs

# AWS Infrastructure Outputs
output "aws_ecr_repository_url" {
  description = "The Amazon ECR repository URL used for pushing container images"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "aws_ecr_repository_arn" {
  description = "Amazon Resource Name (ARN) of the created ECR repository"
  value       = aws_ecr_repository.app_repo.arn
}

output "aws_apprunner_service_url" {
  description = "Public HTTPS endpoint for the AWS App Runner container service"
  value       = "https://${aws_apprunner_service.app_service.service_url}"
}

output "aws_apprunner_service_id" {
  description = "Unique Identifier of the AWS App Runner service"
  value       = aws_apprunner_service.app_service.service_id
}

output "aws_ecs_cluster_name" {
  description = "Name of the ECS cluster for Fargate task workloads"
  value       = aws_ecs_cluster.app_cluster.name
}

# Azure Infrastructure Outputs
output "azure_resource_group_name" {
  description = "Name of the deployed Azure Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "azure_acr_name" {
  description = "Alphanumeric name of the Azure Container Registry (ACR)"
  value       = azurerm_container_registry.acr.name
}

output "azure_acr_login_server" {
  description = "Azure ACR login server domain endpoint"
  value       = azurerm_container_registry.acr.login_server
}

output "azure_acr_admin_username" {
  description = "Admin username for authenticating with Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "azure_app_service_name" {
  description = "Name of the Azure Linux App Service Web App"
  value       = azurerm_linux_web_app.app.name
}

output "azure_app_service_url" {
  description = "Public HTTPS endpoint of the deployed Azure App Service container"
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}
