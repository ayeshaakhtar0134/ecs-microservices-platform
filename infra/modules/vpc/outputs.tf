output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.this[*].id
}

output "flow_log_group_name" {
  value = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
