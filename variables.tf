variable "aws_region" {
  type    = string
  default = "ap-south-2"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "app_name" {
  type    = string
  default = "taskmaster"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "fargate_cpu" {
  type    = number
  default = 1024
}

variable "fargate_memory" {
  type    = number
  default = 2048
}

variable "enable_container_insights" {
  type    = bool
  default = true
}

variable "db_name" {
  type    = string
  default = "myapp"
}

variable "db_username" {
  type    = string
  default = "task"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_platform" {
  type    = string
  default = "org.hibernate.dialect.PostgreSQLDialect"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}