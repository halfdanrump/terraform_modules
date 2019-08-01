output "scheduled_task_arn" {
  value = "${aws_ecs_task_definition.scheduled_task.arn}"
}
