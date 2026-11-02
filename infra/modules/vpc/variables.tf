variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all AZs (cheaper, less available)"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs (rejected traffic) to CloudWatch Logs"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  type    = number
  default = 30
}
