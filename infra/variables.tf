variable "project" {
  type    = string
  default = "ecs-platform"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "github_repository" {
  description = "owner/repo allowed to deploy through GitHub Actions OIDC"
  type        = string
  default     = "ayeshaakhtar0134/ecs-microservices-platform"
}

variable "image_tags" {
  description = "Image tag per service. CI overrides this on deploy."
  type        = map(string)
  default = {
    api    = "latest"
    worker = "latest"
  }
}

variable "alert_email" {
  description = "Email that receives CloudWatch alarm notifications (empty = no subscription)"
  type        = string
  default     = ""
}
