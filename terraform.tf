terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

variable "yandex_cloud_token" {
  type        = string
  description = "Данная переменная потребует ввести секретный токен в консоли при запуске terraform plan/apply"
}

provider "yandex" {
  token     = var.yandex_cloud_token 
  cloud_id  = "b1g4hl204viqn59ct85b"
  folder_id = "b1g010mi049m159v5u2f"
  zone      = "ru-central1-b"
}

#vm
resource "yandex_compute_instance" "vm" {
  count       = 2
  name        = "bodrahost${count.index + 1}"
  hostname    = "bodrahost${count.index + 1}"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  
  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = "fd8s4a9mnca2bmgol2r8"
      size     = 8
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.bodrasub-b.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

#network
resource "yandex_vpc_network" "bodranet" {
  name = "bodranet"
}

#subnet
resource "yandex_vpc_subnet" "bodrasub-b" {
  name = "bodrasub-b"
  v4_cidr_blocks = ["192.168.0.0/24"]
  zone           = "ru-central1-b"
  network_id     = "${yandex_vpc_network.bodranet.id}"
}

#target group
resource "yandex_lb_target_group" "bodra-tg" {
  name      = "bodra-tg"

  target {
    subnet_id = "${yandex_vpc_subnet.bodrasub-b.id}"
    address   = "${yandex_compute_instance.vm[0].network_interface.0.ip_address}"
  }

  target {
    subnet_id = "${yandex_vpc_subnet.bodrasub-b.id}"
    address   = "${yandex_compute_instance.vm[1].network_interface.0.ip_address}"
  }
}

#network load balancer
resource "yandex_lb_network_load_balancer" "bodra-net-lb" {
  name = "bodra-net-lb"

  listener {
    name = "web-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_lb_target_group.bodra-tg.id}"

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
