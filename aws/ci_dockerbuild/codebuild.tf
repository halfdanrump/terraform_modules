/*
Auxiliary resources
*/


resource "aws_ecr_repository" "docker_repo" {
  name = "${var.name}_${var.environment}"
  tags = {
    Name = "${var.name}_${var.environment}"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}

resource "aws_ecr_lifecycle_policy" "count_policy" {
  repository = "${aws_ecr_repository.docker_repo.name}"

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}



/*
Resources for DockerBuild build project
*/

resource "aws_cloudwatch_log_group" "dockerbuild" {
  name = "dockerbuild_${var.name}_${var.environment}"
  tags = {
    Name = "dockerbuild_${var.name}_${var.environment}"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}


resource "aws_iam_role" "dockerbuild_role" {
  name   = "${var.name}_${var.environment}_dockerbuild_role"
  assume_role_policy = "${data.aws_iam_policy_document.dockerbuild_assume_role_policy.json}"
  tags = {
    Name = "${var.name}_${var.environment}_dockerbuild_role"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}

resource "aws_iam_role_policy" "dockerbuild_role_policy" {
  name   = "${var.name}_${var.environment}_docker_build_role_policy"
  role = "${aws_iam_role.dockerbuild_role.name}"
  policy = "${data.aws_iam_policy_document.dockerbuild_policy.json}"
}

resource "aws_codebuild_project" "dockerbuild" {
  name          = "${var.name}_${var.environment}_DockerBuild"
  description   = "builds docker image ${var.name}_${var.environment}"
  build_timeout = "${var.dockerbuild_timeout}"
  service_role  = "${aws_iam_role.dockerbuild_role.arn}"
  encryption_key = "${data.aws_kms_alias.s3kmskey.arn}"
  artifacts {
    type = "NO_ARTIFACTS"
  }
  cache = {
    location = "${aws_s3_bucket.artifacts.bucket}/${var.name}/${var.environment}"
    type = "S3"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/docker:18.09.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }
  source {
    type                  = "GITHUB"
    location              = "http://github.com/${var.git_organization}/${var.git_repo}/tree/${var.git_branch}"
    buildspec             = "${var.dockerbuild_buildspec_path}"
    git_clone_depth       = 1
    report_build_status   = false
    insecure_ssl          = false
    report_build_status   = false
  }
  tags = {
    Name = "${var.name}_${var.environment}_docker_build"
    #created_t = "${timestamp()}"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}

/*
Resources for UnitTest build project
*/


resource "aws_cloudwatch_log_group" "unittest" {
  name = "unittest_${var.name}_${var.environment}"
  tags = {
    Name = "unittest_${var.name}_${var.environment}"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}


resource "aws_iam_role" "unittest_role" {
  name   = "${var.name}_${var.environment}_unittest_role"
  assume_role_policy = "${data.aws_iam_policy_document.unittest_assume_role_policy.json}"
  tags = {
    Name = "${var.name}_${var.environment}_unittest_role"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}

resource "aws_iam_role_policy" "unittest_role_policy" {
  name   = "${var.name}_${var.environment}_unittest_role_policy"
  role = "${aws_iam_role.unittest_role.name}"
  policy = "${data.aws_iam_policy_document.unittest_policy.json}"
}


resource "aws_codebuild_project" "unittest" {
  name          = "${var.name}_${var.environment}_UnitTests"
  build_timeout = "${var.unittest_timeout}"
  service_role  = "${aws_iam_role.unittest_role.arn}"
  encryption_key = "${data.aws_kms_alias.s3kmskey.arn}"
  artifacts {
    type = "NO_ARTIFACTS"
  }
  cache = {
    type = "NO_CACHE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/python:3.6.5"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
  }
  source {
    type                  = "GITHUB"
    location              = "http://github.com/${var.git_organization}/${var.git_repo}/tree/${var.git_branch}"
    buildspec             = "${var.unittest_buildspec_path}"
    git_clone_depth       = 1
    report_build_status   = false
    insecure_ssl          = false
    report_build_status   = false
  }
  vpc_config = {
    security_group_ids = ["sg-ebf7eb87", "sg-eaf7eb86"]
    subnets = ["subnet-4654242f"]
    vpc_id = "vpc-4d364624"
  }
  tags = {
    Name = "${var.name}_${var.environment}_unit_tests"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}
