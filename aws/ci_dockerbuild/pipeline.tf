/*
IAM resources
*/
resource "aws_iam_role" "codepipeline_role" {
  name   = "codepipeline_${var.name}_${var.environment}"
  assume_role_policy = "${data.aws_iam_policy_document.codepipeline_assume_role_policy.json}"
  tags = {
    Name = "${var.name}_${var.environment}"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}

resource "aws_iam_role_policy" "codepipeline_role_policy" {
  name   = "codepipeline_${var.name}_${var.environment}"
  role = "${aws_iam_role.codepipeline_role.name}"
  policy = "${data.aws_iam_policy_document.codepipeline_policy.json}"
}


resource "aws_s3_bucket" "artifacts" {
  bucket = "cicd-codepipeline-${var.name}-${var.environment}"
  acl    = "private"
  force_destroy = true
  tags = {
    Name = "${var.name}_${var.environment}"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}

/*
Pipeline resource for building docker image and pushing to ECR
*/

resource "aws_codepipeline" "deploy_pipeline" {
  name     = "${var.name}_${var.environment}"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.artifacts.bucket}"
    type     = "S3"

    encryption_key {
      id   = "${data.aws_kms_alias.s3kmskey.arn}"
      type = "KMS"
    }
  }

  stage {
    name = "Source"
    action = {
      name = "DownloadSource"
      category = "Source"
      configuration = {
        Branch = "${var.git_branch}"
        Owner = "${var.git_organization}"
        PollForSourceChanges = false
        Repo = "${var.git_repo}"
        OAuthToken = "${aws_ssm_parameter.github_webhook_secret.value}"
      }
      output_artifacts = ["SourceCode"]
      owner = "ThirdParty"
      provider = "GitHub"
      run_order = 1
      version = 1
    }
  }

  stage {
    name = "RunTests"
    action = {
      category = "Test"
      configuration = {
        ProjectName = "${aws_codebuild_project.unittest.name}"
      }
      input_artifacts = ["SourceCode"]
      name = "runTests"
      owner = "AWS"
      provider = "CodeBuild"
      run_order = 2
      version = 1
    }
  }

  stage {
    name = "BuildImage"
    action = {
      category = "Build"
      configuration = {
        ProjectName = "${aws_codebuild_project.dockerbuild.name}"
      }
      input_artifacts = ["SourceCode"]
      name = "buildImage"
      output_artifacts = ["DockerImage"]
      owner = "AWS"
      provider = "CodeBuild"
      run_order = 3
      version = 1
    }
  }
}

/*
Webhook config
*/

resource "aws_ssm_parameter" "github_webhook_secret" {
  name        = "/${var.name}/${var.environment}/github/webhook"
  description = "used by the CICD pipeline to create/destroy github webhooks"
  type        = "SecureString"
  value       = "${var.github_webhook_token}"
  tags = {
    Name = "${var.name}_${var.environment}"
    Created_by = "terraform"
    Module    = "cicd_${local.module_version}"
  }
}

resource "aws_codepipeline_webhook" "webhook" {
  name            = "${var.name}_${var.environment}_TERRAFORM"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = "${aws_codepipeline.deploy_pipeline.name}"

  authentication_configuration {
    secret_token = "${aws_ssm_parameter.github_webhook_secret.value}"
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/${var.git_branch}"
  }
}

resource "github_repository_webhook" "webhook" {
  repository = "${var.git_repo}"

  configuration {
    url          = "${aws_codepipeline_webhook.webhook.url}"
    content_type = "json"
    insecure_ssl = false
    secret       = "${aws_ssm_parameter.github_webhook_secret.value}"
  }

  events = ["push"]
  active = true
}
