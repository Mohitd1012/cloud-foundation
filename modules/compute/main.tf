# modules/compute/main.tf — ALB + Auto Scaling Group + least-privilege IAM.
#
# Demonstrates: horizontal scaling (ASG), high availability (multi-AZ), health checks,
# IAM instance profile (NO long-lived keys on the box), SSM access (no SSH/bastion).
#
# AZURE: ALB -> Application Gateway/Load Balancer, ASG -> VM Scale Set, instance profile ->
#        Managed Identity.
# GCP:   ALB -> Cloud Load Balancing, ASG -> Managed Instance Group, instance profile ->
#        attached Service Account.

# ---------------- IAM: instance role with LEAST PRIVILEGE ----------------
# WHY (interview, Troubleshooting Q9-adjacent): the EC2 box assumes this role and gets
# SHORT-LIVED credentials from the instance metadata service. Never bake access keys into AMIs.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# SSM managed policy = shell access via Session Manager (no port 22, no bastion, fully audited).
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Grant read of ONLY this app's DB secret (least privilege — not secretsmanager:* on all secrets).
resource "aws_iam_role_policy" "read_db_secret" {
  name = "${var.name}-read-db-secret"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_secret_arn] # ✅ scoped to one ARN, not "*"
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app-profile"
  role = aws_iam_role.app.name
}

# ---------------- Launch template ----------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix            = "${var.name}-lt-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.app_sg_id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  # Minimal user-data: a health endpoint so the ALB target group has something to probe.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "ok" > /usr/share/nginx/html/healthz
    # serve on the app port the ALB expects
    sed -i "s/listen       80;/listen       ${var.app_port};/" /etc/nginx/nginx.conf
    systemctl enable --now nginx
  EOF
  )

  metadata_options {
    http_tokens = "required" # ✅ IMDSv2 only — mitigates SSRF credential theft (security best practice)
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }
}

# ---------------- ALB (public) ----------------
resource "aws_lb" "app" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids # ✅ ALB lives in PUBLIC subnets
  tags               = var.tags
}

# Target group with a HEALTH CHECK (Troubleshooting Q12: wrong path -> all targets unhealthy -> 502).
resource "aws_lb_target_group" "app" {
  name     = "${var.name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/healthz" # ✅ must match the endpoint the app actually serves
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }
  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
  # PROD: add an HTTPS (443) listener with an ACM cert and redirect 80->443.
}

# ---------------- Auto Scaling Group (in PRIVATE app subnets) ----------------
resource "aws_autoscaling_group" "app" {
  name                = "${var.name}-asg"
  vpc_zone_identifier = var.app_subnet_ids # ✅ instances are PRIVATE (egress via NAT)
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB" # ✅ replace instances the ALB marks unhealthy

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Zero-downtime instance refresh when the launch template changes (mirrors K8s rolling update).
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }
}

# Scale on CPU — demonstrates horizontal autoscaling (the cloud-fundamentals "elasticity" answer).
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0 # scale to keep avg CPU ~60%
  }
}
