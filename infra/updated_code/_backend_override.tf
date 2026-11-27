terraform {
  backend "local" {
    path = "/tmp/terraform-updated-code.tfstate"
  }
}
