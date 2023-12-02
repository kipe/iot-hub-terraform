terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
      version = "2.34.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.2"
    }
    local = {
      source = "hashicorp/local"
      version = "2.4.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
    http = {
      source = "hashicorp/http"
      version = "3.4.0"
    }
  }
}

variable "scaleway_access_key" {
  type = string
  sensitive = true
}

variable "scaleway_secret_key" {
  type = string
  sensitive = true
}

variable "scaleway_project_id" {
  type = string
  sensitive = true
}

provider "scaleway" {
  zone = "fr-par-1"
  region = "fr-par"
  access_key = var.scaleway_access_key
  secret_key = var.scaleway_secret_key
  project_id = var.scaleway_project_id
}
