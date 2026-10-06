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
  restart = "unless-stopped"
  name    = "meu-container-web"
  image   = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }

  networks_advanced {
    name = docker_network.monitoring.name
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
  restart = "unless-stopped"
  name    = "meu-container-db"
  image   = docker_image.postgres.image_id
  env     = ["POSTGRES_PASSWORD=${var.postgres_password}"]

  ports {
    internal = 5432
    external = 5432
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  volumes {
    volume_name    = docker_volume.db_data.name
    container_path = "/var/lib/postgresql/data"
  }
}

# Lab 2: pipeline validada antes de aplicar.

resource "docker_network" "monitoring" {
  name = "monitoring-net"
}

resource "docker_image" "cadvisor" {
  name = "gcr.io/cadvisor/cadvisor:latest"
}

resource "docker_container" "cadvisor" {
  restart    = "unless-stopped"
  name       = "cadvisor"
  image      = docker_image.cadvisor.image_id
  privileged = true

  ports {
    internal = 8080
    external = 8081
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }

  volumes {
    host_path      = "/"
    container_path = "/rootfs"
    read_only      = true
  }
  volumes {
    host_path      = "/var/run"
    container_path = "/var/run"
    read_only      = true
  }
  volumes {
    host_path      = "/sys"
    container_path = "/sys"
    read_only      = true
  }
  volumes {
    host_path      = "/var/lib/docker"
    container_path = "/var/lib/docker"
    read_only      = true
  }
  volumes {
    host_path      = "/dev/disk"
    container_path = "/dev/disk"
    read_only      = true
  }
  devices {
    host_path      = "/dev/kmsg"
    container_path = "/dev/kmsg"
    permissions    = "rwm"
  }
}

resource "docker_image" "prometheus" {
  name = "prom/prometheus:latest"
}

resource "docker_container" "prometheus" {
  restart = "unless-stopped"
  name    = "prometheus"
  image   = docker_image.prometheus.image_id

  ports {
    internal = 9090
    external = 9090
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
  volumes {
    host_path      = "${path.cwd}/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }
}

resource "docker_image" "grafana" {
  name = "grafana/grafana:latest"
}

resource "docker_volume" "grafana_data" {
  name = "meu-projeto-grafana-data"
}

resource "docker_container" "grafana" {
  restart = "unless-stopped"
  name    = "grafana"
  image   = docker_image.grafana.image_id
  env     = ["GF_DASHBOARDS_MIN_REFRESH_INTERVAL=5s"]

  ports {
    internal = 3000
    external = 3000
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
  volumes {
    volume_name    = docker_volume.grafana_data.name
    container_path = "/var/lib/grafana"
  }
  volumes {
    host_path      = "${path.cwd}/grafana/provisioning"
    container_path = "/etc/grafana/provisioning"
    read_only      = true
  }
  volumes {
    host_path      = "${path.cwd}/grafana/dashboards"
    container_path = "/var/lib/grafana/dashboards"
    read_only      = true
  }
}

resource "docker_image" "alertas" {
  name = "python:3.13-alpine"
}

resource "docker_container" "alertas" {
  restart = "unless-stopped"
  name    = "alertas-local"
  image   = docker_image.alertas.image_id
  command = ["python", "-u", "/app/alertas.py"]

  networks_advanced {
    name = docker_network.monitoring.name
  }
  volumes {
    host_path      = "${path.cwd}/alertas.py"
    container_path = "/app/alertas.py"
    read_only      = true
  }
}
