# Bucket where Athena saves query results
resource "aws_s3_bucket" "athena_results" {
  bucket        = "athlete-pipeline-athena-results-710412005872"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Glue: the catalogue ("label on the box")
resource "aws_glue_catalog_database" "athletes" {
  name = "athlete_pipeline"
}

resource "aws_glue_catalog_table" "results" {
  name          = "results"
  database_name = aws_glue_catalog_database.athletes.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification = "csv"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.processed.bucket}/results/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim" = ","
      }
    }

    columns {
      name = "athlete_id"
      type = "string"
    }
    columns {
      name = "test_date"
      type = "date"
    }
    columns {
      name = "test_name"
      type = "string"
    }
    columns {
      name = "value"
      type = "double"
    }
  }
}

# Athena: the query engine, with its own workgroup
resource "aws_athena_workgroup" "athletes" {
  name          = "athlete-pipeline"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"
    }
  }
}

