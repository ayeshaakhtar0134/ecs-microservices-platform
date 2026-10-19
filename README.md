# ecs-microservices-platform

![terraform](https://github.com/ayeshaakhtar0134/ecs-microservices-platform/actions/workflows/terraform.yml/badge.svg)
![service-api](https://github.com/ayeshaakhtar0134/ecs-microservices-platform/actions/workflows/service-api.yml/badge.svg)
![service-worker](https://github.com/ayeshaakhtar0134/ecs-microservices-platform/actions/workflows/service-worker.yml/badge.svg)

A microservices platform on **AWS ECS Fargate**, built with **Terraform**, deployed by **GitHub Actions** using OIDC (no AWS keys stored in GitHub), and monitored with **CloudWatch**. A Node.js API accepts jobs and puts them on an **SQS** queue; a Python worker processes them, with failed jobs moving to a dead-letter queue. Adding a new service takes one Terraform block, one folder and one 15-line workflow.

## Architecture

```
                 Internet
                    │
             ┌──────┴──────┐
             │     ALB     │  /api/*, /health
             └──────┬──────┘
   ─ ─ ─ ─ ─ ─ ─ ─ ─│─ ─ private subnets (2 AZs) ─ ─ ─ ─ ─ ─ ─ ─ ─
             ┌──────┴──────┐   SendMessage   ┌───────────┐  Receive  ┌──────────────┐
             │ api (Node)  │ ──────────────► │ SQS jobs  │ ────────► │ worker (Py)  │
             │ Fargate x2  │                 └─────┬─────┘           │ Fargate Spot │
             └─────────────┘                after 5 fails            └──────────────┘
                                             ┌─────┴─────┐
                                             │  SQS DLQ  │
                                             └───────────┘

  CloudWatch: logs · 9 alarms · dashboard ──► SNS ──► email
  GitHub Actions ──OIDC──► IAM deploy role ──► ECR push + ECS deploy
```
Export a proper diagram to `docs/architecture.png` (draw.io or Excalidraw) and link it here.

## What's inside

| Area | Details |
|------|---------|
| **Networking** | VPC module (from [aws-terraform-foundation](https://github.com/ayeshaakhtar0134/aws-terraform-foundation)), public/private subnets in 2 AZs, NAT |
| **Compute** | ECS cluster with Fargate + Fargate Spot, Container Insights |
| **Reusable service module** | `infra/modules/ecs-service`: task definition, service, security group, IAM execution + task roles, log group, Cloud Map DNS, optional ALB routing, CPU autoscaling, circuit-breaker rollback |
| **Images** | ECR per service, immutable tags, scan on push, lifecycle policy |
| **Messaging** | SQS jobs queue with long polling, encryption and a dead-letter queue after 5 failed attempts; api can only send, worker can only consume |
| **Monitoring** | 9 CloudWatch alarms (5xx errors, p95 latency, unhealthy tasks, CPU and memory per service, DLQ not empty, queue backlog age) → SNS → email, plus a dashboard for traffic, latency, resources and the queue |
| **Secrets** | Secrets Manager injected at task start, never in state or git |
| **CI/CD** | One reusable workflow (`_service-pipeline.yml`) called by each service with path filters: test → build → Trivy scan → push → deploy |
| **IaC checks** | `terraform fmt`, `validate`, `tflint`, `checkov`, and `plan` via OIDC |

## Repository layout

```
infra/
  main.tf, load_balancer.tf, services.tf, secrets.tf, github_oidc.tf
  queue.tf              SQS jobs queue + DLQ + least-privilege IAM
  monitoring.tf         alarms, SNS topic, CloudWatch dashboard
  modules/vpc/          shared network module
  modules/ecs-service/  reusable module, one instance per microservice
services/
  api/      Node.js (Express) + tests + Dockerfile
  worker/   Python (FastAPI) SQS consumer + tests (moto) + Dockerfile
.github/workflows/
  _service-pipeline.yml   reusable pipeline
  service-api.yml         triggers on services/api/**
  service-worker.yml      triggers on services/worker/**
  terraform.yml           IaC checks + plan
docker-compose.yml        run everything locally
```

## Run locally

```bash
docker compose up --build
curl localhost:3000/health
curl -X POST localhost:3000/api/jobs -H 'content-type: application/json' -d '{"task":"resize"}'
```

## Deploy to AWS

1. **Infra:** `cd infra && terraform init && terraform apply -var alert_email=you@example.com` (confirm the email AWS sends you). The first apply uses the `latest` tag, so tasks won't start until step 4 pushes images.
2. **Outputs:** note `github_deploy_role_arn`, `alb_url` and `dashboard_url`.
3. **GitHub:** Settings → Secrets and variables → Actions → **Variables** → add `AWS_DEPLOY_ROLE_ARN` with the role ARN. Also create an environment named `dev`.
4. **Ship:** push a change under `services/` (or run the workflow manually). Actions builds, scans, pushes to ECR and rolls out to ECS.
5. **Test:** `curl <alb_url>/health`, then submit a job and watch it on the dashboard:
   `curl -X POST <alb_url>/api/jobs -H 'content-type: application/json' -d '{"task":"resize"}'`
   Send `{"fail":true}` to see a job retry 5 times, land in the DLQ and trigger the alarm.

## Tear down

```bash
cd infra && terraform destroy
```

## Estimated cost (dev, running 24/7)

| Item | ≈ per month |
|------|-------------|
| NAT Gateway | $32 |
| ALB | $16 |
| 3 small Fargate tasks (1 on Spot) | $20 |
| CloudWatch logs, 9 alarms, dashboard | $5 |
| SQS, SNS, ECR, Secrets Manager | $1 |

Destroy when not in use. A few hours of testing costs well under $1.

## Design decisions

- **ECS over EKS:** for a handful of services, Fargate means no nodes to patch and much less to operate.
- **One reusable module per service** keeps every service consistent (logging, IAM, autoscaling) and makes new services a few lines.
- **Terraform owns infrastructure, CI owns image versions.** `ignore_changes = [task_definition]` stops the two from fighting.
- **OIDC restricted to `main`** of this repo, so forks and branches can't deploy.
- **Circuit breaker with rollback** automatically reverts a bad deploy.
- **Queue between api and worker** so a slow or crashed worker never makes the API fail; jobs wait safely and the DLQ catches poison messages.
- **Alarms on symptoms users feel** (errors, latency, backlog age) rather than only on CPU.

## What I learned

- *Add 3–5 points after deploying it yourself.*

## Roadmap

- [ ] HTTPS with ACM and Route 53
- [ ] Blue/green deploys with CodeDeploy
- [x] SQS queue between api and worker
- [x] CloudWatch dashboard and alarms per service
- [ ] Scale the worker on queue depth instead of CPU
