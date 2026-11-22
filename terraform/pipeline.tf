# 1. Bucket for cleaned data
resource "aws_s3_bucket" "processed" {
  bucket = "athlete-pipeline-processed-710412005872"
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Zip the Python code so Lambda can run it
data "archive_file" "processor" {
  type        = "zip"
  source_file = "${path.module}/lambda/process_results.py"
  output_path = "${path.module}/build/process_results.zip"
}

# 6. Logs, kept for 14 days
resource "aws_cloudwatch_log_group" "processor" {
  name              = "/aws/lambda/athlete-pipeline-processor"
  retention_in_days = 14
}

# 3. Role: who the Lambda "is"
resource "aws_iam_role" "processor" {
  name = "athlete-pipeline-processor"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# 3. Policy: exactly what it may do, nothing more
resource "aws_iam_role_policy" "processor" {
  name = "athlete-pipeline-processor"
  role = aws_iam_role.processor.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.raw.arn}/*" },
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = "${aws_s3_bucket.processed.arn}/*" },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.processor.arn}:*" }
    ]
  })
}

# The function itself
resource "aws_lambda_function" "processor" {
  function_name    = "athlete-pipeline-processor"
  role             = aws_iam_role.processor.arn
  runtime          = "python3.13"
  handler          = "process_results.handler"
  filename         = data.archive_file.processor.output_path
  source_code_hash = data.archive_file.processor.output_base64sha256
  timeout          = 30

  environment {
    variables = { PROCESSED_BUCKET = aws_s3_bucket.processed.bucket }
  }

  depends_on = [aws_cloudwatch_log_group.processor]
}

# 5. Allow S3 to call the Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.processor.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.raw.arn
  source_account = "710412005872"
}

# 4. Trigger: new .csv in raw bucket, so run the Lambda
resource "aws_s3_bucket_notification" "raw_upload" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
