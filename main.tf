terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "original_images_bucket" {
  bucket = "bucket1"
  acl = "private"
}

resource "aws_s3_bucket" "resized_images_bucket" {
  bucket = "bucket2"
  acl = "private"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "test_role"

  assume_role_policy = jsondecode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name = "lambda_execution_policy"
  policy = jsondecode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.original_images_bucket.arn}/*",
        "${aws_s3_bucket.resized_images_bucket.arn}/*"
      ]
    }
  ]
})
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
    role = aws_iam_role.lambda_execution_role.arn
    policy = aws_iam_policy.iam_role.policy.arn
}

#Lambda Function

data "archive_file" "lambda_fucntion_zip" {
    type = "zip"
    source_file = "lambda_fucntion"
    output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "image_processing_lambda" {
    function_name = "image-processing-lambda"
    handler = "lambda_function.lambda_handler"
    runtime = "python3.8"
    filename = data.archive_file.lambda_fucntion_zip.output_path
    source_code_hash = data.archive_file.lambda_fucntion_zip.output_base64sha256
    role = aws_iam_role.lambda_execution_role.arn

    environment {
      variables = {
        RESIZED_BUCKET_NAME = aws_s3_bucket.resized_images_bucket.id
      }
    }
}


resource "aws_lambda_permission" "image_processing_lambda_permission" {
  statement_id  = "AllowS3Invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processing_lambda.function_name
  principal     = "s3.amazonaws.com"

  source_arn = aws_s3_bucket.original_images_bucket.arn
}
