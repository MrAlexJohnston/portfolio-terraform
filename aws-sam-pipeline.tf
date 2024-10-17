resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "portfolio-aws-sam-bucket-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}"

  force_destroy = true
}

resource "aws_iam_role" "pipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy" "pipeline_policy" {
  role = aws_iam_role.pipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:*",
          "codebuild:*",
          "codecommit:*",
          "cloudformation:*",
          "iam:PassRole"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "codestar-connections:UseConnection",
        Resource = "arn:aws:codestar-connections:eu-west-2:769355695078:connection/1be98307-7c50-4389-9fa9-1117620d535c"
      }
    ]
  })
}

resource "aws_iam_role" "cf_role" {
  name = "cloudformation-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "cloudformation.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "cf_role_policy" {
  role = aws_iam_role.cf_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = [
        "iam:PassRole",
        "s3:*",
        "cloudformation:*",
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_codepipeline" "my_pipeline" {
  name = "PortfolioAwsSamPipeline"
  role_arn = aws_iam_role.pipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type = "S3"
  }
  stage {
    name = "Source"
    action {
      name            = "GitHub_Source"
      category        = "Source"
      owner           = "AWS"
      provider        = "CodeStarSourceConnection"
      version         = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn   = "arn:aws:codestar-connections:eu-west-2:769355695078:connection/1be98307-7c50-4389-9fa9-1117620d535c"
        FullRepositoryId = "MrAlexJohnston/portfolio-aws-sam"
        BranchName       = "main"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }
  stage {
    name = "Deploy"
    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CloudFormation"
      input_artifacts  = ["build_output"]
      version          = "1"
      configuration = {
        StackName           = "PortfolioAwsSam"
        Capabilities        = "CAPABILITY_NAMED_IAM,CAPABILITY_AUTO_EXPAND"
        TemplatePath        = "build_output::packaged.yaml"
        ActionMode          = "CREATE_UPDATE"
        RoleArn             = aws_iam_role.cf_role.arn
        ParameterOverrides  = jsonencode({
          SubnetId1       = aws_subnet.public_subnet[0].id
          SubnetId2       = aws_subnet.public_subnet[1].id
          SubnetId3       = aws_subnet.public_subnet[2].id
          SecurityGroupId = aws_security_group.lambda_security_group.id
        })
      }
    }
  }
}

resource "aws_codebuild_project" "build_project" {
  name          = "BuildProject"
  description   = "CodeBuild project for building the AWS SAM application"
  build_timeout = 30

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    environment_variable {
      name  = "PACKAGE_BUCKET"
      value = aws_s3_bucket.artifact_bucket.bucket
    }
    environment_variable {
      name  = "AWS_REGION"
      value = data.aws_region.current.name
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/MrAlexJohnston/portfolio-aws-sam"
    buildspec       = "buildspec.yml"  # Define the buildspec file location
    git_clone_depth = 1
  }

  # Define where the build artifacts should be stored (e.g., S3 bucket)
  artifacts {
    type = "S3"
    location = aws_s3_bucket.artifact_bucket.bucket
    path = "build-output"
  }

  service_role = aws_iam_role.codebuild_role.arn
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:eu-west-2:769355695078:log-group:/aws/codebuild/*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.artifact_bucket.arn}/*"
      }
    ]
  })
}