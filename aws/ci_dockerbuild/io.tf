variable account_id{} # something that looks like 211377887982
variable name {}  # project name
variable environment {}  # name of the environment, e.g. staging or production
variable github_webhook_token {}  #
variable git_repo {} # name of the github repo
variable git_branch {
  default = "production"
  }
variable git_organization {
  default = "SnapDish"
  }

variable dockerbuild_timeout {
  default = 5
}
variable unittest_timeout {
  default = 5
}
variable unittest_buildspec_path {}
variable dockerbuild_buildspec_path {}

locals {
  module_version = "1.0"
}
