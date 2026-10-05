terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "web" {
  name  = "meu-container-web"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8081
  }

  volumes {
    host_path      = "${path.cwd}/site"
    container_path = "/usr/share/nginx/html"
    read_only      = true
  }
}

output "web_url" {
  value = "http://localhost:${one(docker_container.web.ports).external}"
}

variable "postgres_password" {
  description = "Senha local do PostgreSQL; informe por TF_VAR_postgres_password."
  type        = string
  sensitive   = true
}

resource "docker_volume" "db_data" {
  name = "meu-projeto-db-data"
}

resource "docker_image" "postgres" {
  name = "postgres:16"
}

resource "docker_container" "db" {
  name  = "meu-container-db"
  image = docker_image.postgres.image_id
  env   = ["POSTGRES_PASSWORD=${var.postgres_password}"]

  ports {
    internal = 5432
    external = 5432
  }

  volumes {
    volume_name    = docker_volume.db_data.name
    container_path = "/var/lib/postgresql/data"
  }
}

# Lab 2: pipeline validada antes de aplicar.
