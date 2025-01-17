variable "aws_region" {
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = map(string)
  default = {
    "ap-south-1a" = "10.0.1.0/24"
    "ap-south-1b" = "10.0.2.0/24"
  }
}

variable "container_port" {
  type        = number
  default     = 8080
}

variable "app_name" {
  type        = string
  default     = "my-app"
}

variable "environment" {
  type        = string
  default     = "prod"
}

variable "ecs_task_cpu" {
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  type        = number
  default     = 2048
}

variable "ecs_task_desired_count" {
  type        = number
  default     = 1
}

variable "log_retention_days" {
  type        = number
  default     = 30
}

variable "db_password" {
  sensitive = true
}

variable "db_port" {
  type        = number
  default     = 16584
}