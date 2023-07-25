provider "aws" {
  region = "eu-west-1" 
}

variable "agencies" {
  default = ["agency1", "agency2", "agency3"]
  type    = list(string)
}

resource "aws_s3_bucket" "file_storage" {
  bucket = "your-unique-bucket-name"  # Change to a unique bucket name
  acl    = "private"
}

resource "aws_iam_role" "sftp_role" {
  name = "sftp_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "sftp_policy_attachment" {
  name       = "sftp_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonTransferServiceRolePolicy"
  roles      = [aws_iam_role.sftp_role.name]
}

resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
}

resource "aws_transfer_user" "sftp_users" {
  for_each  = toset(var.agencies)
  server_id = aws_transfer_server.sftp_server.id
  user_name = each.key
  role      = aws_iam_role.sftp_role.arn
}

resource "aws_iam_policy" "sftp_user_policy" {
  for_each    = toset(var.agencies)
  name        = "sftp_user_policy_${each.key}"
  description = "Policy for SFTP user ${each.key}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.file_storage.arn,
          "${aws_s3_bucket.file_storage.arn}/*"
        ]
        Condition = {
          StringEqualsIfExists = {
            "aws:username" = each.key
          }
        }
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "sftp_user_policy_attachment" {
  for_each      = toset(var.agencies)
  user          = aws_transfer_user.sftp_users[each.key].name
  policy_arn    = aws_iam_policy.sftp_user_policy[each.key].arn
}

output "sftp_endpoint" {
  value = aws_transfer_server.sftp_server.endpoint
}

output "s3_bucket_name" {
  value = aws_s3_bucket.file_storage.bucket
}

