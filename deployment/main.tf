data "external" "env" {
  program = ["${path.module}/env.sh"]
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "LambdaExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_lambda_function" "update_ships_function" {
  function_name = "UpdateShipsFunction"
  handler      = "com.solarwind.lambda.UpdateShipsFunction::handleRequest"
  runtime      = "java17"
  timeout      = 60

  # Specify your Lambda function code location
  filename     = "/Users/vhalme/projects/solarwind/solarwind-aws-lambda/target/solarwind-aws-lambda-0.0.1-SNAPSHOT.jar"
  source_code_hash = filebase64sha256("/Users/vhalme/projects/solarwind/solarwind-aws-lambda/target/solarwind-aws-lambda-0.0.1-SNAPSHOT.jar")
  
  role         = aws_iam_role.lambda_execution_role.arn

  environment {
    variables = {
      DB_SERVER = data.external.env.result["DB_SERVER"],
      DB_USER = data.external.env.result["DB_USER"],
      DB_PASSWORD = data.external.env.result["DB_PASSWORD"]
    }
  }

}

resource "aws_iam_policy" "lambda_policy" {

  name        = "LambdaCloudwatchPolicy"
  description = "IAM policy for Lambda function"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "lambda:InvokeFunction",
        Effect   = "Allow",
        Resource = aws_lambda_function.update_ships_function.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_iam_role" "event_invocation_role" {
  name = "EventInvocationRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "update_ships_event_rule" {
  
  name        = "UpdateShipsEventRule"
  description = "Scheduled ship update event rule"
  schedule_expression = "cron(0 * * * ? *)"

  # Define the event pattern to match
  event_pattern = jsonencode({
    source = ["aws.events"],
    detail = {
      eventName: ["myEvent"]
    }
  })
  
  role_arn            = aws_iam_role.event_invocation_role.arn
}

resource "aws_cloudwatch_event_target" "update_ships_event_target" {
  rule      = aws_cloudwatch_event_rule.update_ships_event_rule.name
  target_id = "UpdateShipsEventTarget"
  arn       = aws_lambda_function.update_ships_function.arn
}

resource "aws_lambda_permission" "cloudwatch_lambda_permission" {
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_ships_function.function_name
  principal     = "events.amazonaws.com"
  source_arn   = aws_cloudwatch_event_rule.update_ships_event_rule.arn
}

