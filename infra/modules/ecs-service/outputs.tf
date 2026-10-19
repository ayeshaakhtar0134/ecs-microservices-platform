output "service_name" {
  value = aws_ecs_service.this.name
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "log_group" {
  value = aws_cloudwatch_log_group.this.name
}

output "task_role_name" {
  value = aws_iam_role.task.name
}

output "target_group_arn_suffix" {
  description = "Null when the service isn't behind the load balancer"
  value       = var.load_balancer == null ? null : aws_lb_target_group.this[0].arn_suffix
}
