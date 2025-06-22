terraform {
  backend "s3" {
    bucket       = "project3-tfstate-osi45"
    key          = "project3/terraform.tfstate"
    region       = "us-east-1"

    encrypt      = true
  }
}
