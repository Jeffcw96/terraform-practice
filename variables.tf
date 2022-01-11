variable "aws_env" {
  type = object({
    access = string
    secret = string
  })
}

variable "environment" {
  type = string
}