variable "name" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "environment" {
  type    = map(string)
  default = {}
}

variable "secrets" {
  description = "Env var name => Secrets Manager secret ARN, injected at task start"
  type        = map(string)
  default     = {}
}

variable "namespace_id" {
  description = "Cloud Map namespace for service-to-service DNS"
  type        = string
}

variable "ingress_sg_ids" {
  description = "Security groups allowed to reach this service's port"
  type        = list(string)
  default     = []
}

variable "use_fargate_spot" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "load_balancer" {
  description = "Set to expose the service through the shared ALB"
  type = object({
    listener_arn      = string
    path_patterns     = list(string)
    priority          = number
    health_check_path = string
  })
  default = null
}
