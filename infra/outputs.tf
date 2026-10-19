output "alb_url" {
  value = "http://${aws_lb.this.dns_name}"
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecr_repositories" {
  value = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "github_deploy_role_arn" {
  description = "Save as the AWS_DEPLOY_ROLE_ARN secret in GitHub"
  value       = aws_iam_role.github_deploy.arn
}

output "jobs_queue_url" {
  value = aws_sqs_queue.jobs.url
}

output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.platform.dashboard_name}"
}
