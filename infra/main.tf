locals {
  name = "${var.project}-${var.environment}"
  azs  = ["${var.region}a", "${var.region}b"]
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source             = "./modules/vpc"
  name               = local.name
  cidr_block         = var.vpc_cidr
  azs                = local.azs
  single_nat_gateway = true
}

resource "aws_ecs_cluster" "this" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# Private DNS so services can call each other as <service>.<namespace>
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "${var.environment}.internal"
  vpc  = module.vpc.vpc_id
}

resource "aws_ecr_repository" "service" {
  for_each             = toset(["api", "worker"])
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}
