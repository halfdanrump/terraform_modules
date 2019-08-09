
# CloudWatch log groups
resource "aws_cloudwatch_log_group" "task_logs" {
  for_each = var.log_groups
  # name = each.value
  name = each.value
  tags = {
    name = each.key
    created_by = "terraform"
  }
}

resource "aws_ecs_task_definition" "scheduled_task" {
  family                   = "${var.name}_${var.environment}_scheduled_task"
  container_definitions    = "${var.container_definitions}"
  requires_compatibilities = ["${var.launch_type}"]
  network_mode             = "${var.network_mode}"
  execution_role_arn       = "arn:aws:iam::${var.account_id}:role/ecsTaskExecutionRole"
  cpu                      = "${var.cpu}"
  memory                   = "${var.memory}"
}

## Cloudwatch event

resource "aws_cloudwatch_event_rule" "scheduled_task" {
  name                = "${var.name}_${var.environment}_scheduled_task"
  description         = "Run ${var.name}_${var.environment} task at a scheduled time (${var.schedule_expression})"
  schedule_expression = "${var.schedule_expression}"
}

resource "aws_cloudwatch_event_target" "scheduled_task" {
  target_id = "${var.name}_${var.environment}_scheduled_task_target"
  rule      = "${aws_cloudwatch_event_rule.scheduled_task.name}"
  arn       = "${var.cluster_arn}"
  role_arn  = "arn:aws:iam::${var.account_id}:role/ecsEventsRole"

  ecs_target {
    task_count          = "${var.task_count}"
    task_definition_arn = "${aws_ecs_task_definition.scheduled_task.arn}"
    launch_type         = "${var.launch_type}"
    platform_version    = "LATEST"

     network_configuration {
      subnets         = "${var.subnets}"
      security_groups = "${var.security_groups}"
      assign_public_ip = "${var.assign_public_ip}"
    }
  }
}
