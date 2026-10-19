# One block per microservice. Adding a service = adding a block here
# plus a folder under services/ and a small workflow.

module "service_api" {
  source = "./modules/ecs-service"

  name               = "api"
  cluster_id         = aws_ecs_cluster.this.id
  cluster_name       = aws_ecs_cluster.this.name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  image              = "${aws_ecr_repository.service["api"].repository_url}:${var.image_tags["api"]}"
  container_port     = 3000
  cpu                = 256
  memory             = 512
  desired_count      = 2
  namespace_id       = aws_service_discovery_private_dns_namespace.this.id
  ingress_sg_ids     = [aws_security_group.alb.id]
  secrets            = { APP_SECRETS = aws_secretsmanager_secret.app.arn }
  log_retention_days = 14

  environment = {
    WORKER_URL = "http://worker.${aws_service_discovery_private_dns_namespace.this.name}:8000"
  }

  load_balancer = {
    listener_arn      = aws_lb_listener.http.arn
    path_patterns     = ["/api/*", "/health"]
    priority          = 10
    health_check_path = "/health"
  }
}

module "service_worker" {
  source = "./modules/ecs-service"

  name               = "worker"
  cluster_id         = aws_ecs_cluster.this.id
  cluster_name       = aws_ecs_cluster.this.name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  image              = "${aws_ecr_repository.service["worker"].repository_url}:${var.image_tags["worker"]}"
  container_port     = 8000
  cpu                = 256
  memory             = 512
  desired_count      = 1
  namespace_id       = aws_service_discovery_private_dns_namespace.this.id
  ingress_sg_ids     = [module.service_api.security_group_id]
  use_fargate_spot   = true
  log_retention_days = 14
}
