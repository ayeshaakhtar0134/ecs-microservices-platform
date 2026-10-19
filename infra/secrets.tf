# The value is set outside Terraform so it never lands in state or git:
#   aws secretsmanager put-secret-value --secret-id <arn> --secret-string '{"API_KEY":"..."}'
resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name}/app"
  recovery_window_in_days = 0
}
