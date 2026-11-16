##################################
# Environment-Specific Resources
##################################

# --- ECR repository (the private tasks pull images through the VPC endpoints) ---

resource "aws_ecr_repository" "app" {
  name         = "${local.name_prefix}-ecr-app"
  force_delete = var.ecr_force_delete
}

# --- Application load balancer -----------------------------------------

resource "aws_lb" "alb" {
  name               = "${local.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_security_group_id]

  enable_deletion_protection = var.alb_deletion_protection

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

# --- ALB access logs (S3, because the load balancer cannot write them to CloudWatch) ---

data "aws_caller_identity" "current" {}

data "aws_elb_service_account" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${local.name_prefix}-s3-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.alb_logs_force_destroy
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }
  }
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.current.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-tg-app"
  vpc_id      = var.vpc_id
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"

  health_check {
    path    = var.health_check_path
    matcher = "200-399"
  }
}

# HTTPS only: CloudFront reaches the load balancer over TLS using this certificate.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- ECS on Fargate ----------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${local.name_prefix}/ecs/app"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_cluster" "cluster" {
  name = "${local.name_prefix}-ecs-cluster"
}

# Lets ECS read the database secret and decrypt it, so the password is injected at start.
data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [var.secrets_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${local.name_prefix}-ecs-execution-secrets"
  role   = var.task_execution_role_name
  policy = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-ecs-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  depends_on = [aws_iam_role_policy.execution_secrets]

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = var.app_port, protocol = "tcp" }
      ]

      environment = [for key in sort(keys(var.container_environment)) : { name = key, value = var.container_environment[key] }]
      secrets     = var.container_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "${local.name_prefix}-ecs-app"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.https]
}
