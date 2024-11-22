provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
  credentials = file(var.google_credentials)
}

resource "google_compute_instance" "flask_instance" {
  name         = "flask-app-instance"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"

    access_config {
      # This is required to assign a public IP.
    }
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y python3-pip
    pip3 install flask google-cloud-pubsub
    cat <<EOF > /opt/app.py
    from flask import Flask, request
    from google.cloud import pubsub_v1

    app = Flask(__name__)

    @app.route("/", methods=["POST"])
    def receive_message():
        data = request.get_json()
        print(f"Received message: {data}")
        return "Message received", 200

    if __name__ == "__main__":
        app.run(host="0.0.0.0", port=8080)
    EOF

    # Create a systemd service for the Flask app
    cat <<EOF > /etc/systemd/system/flask-app.service
    [Unit]
    Description=Flask App

    [Service]
    ExecStart=/usr/bin/python3 /opt/app.py
    Restart=always
    User=nobody
    Group=nogroup

    [Install]
    WantedBy=multi-user.target
    EOF

    systemctl daemon-reload
    systemctl start flask-app.service
    systemctl enable flask-app.service
  EOT
}

resource "google_pubsub_topic" "flask_topic" {
  name = "flask-app-topic"
}

resource "google_pubsub_subscription" "flask_subscription" {
  name  = "flask-app-subscription"
  topic = google_pubsub_topic.flask_topic.id

  push_config {
    push_endpoint = "http://${google_compute_instance.flask_instance.network_interface.0.access_config.0.nat_ip}:8080/"
  }
}

output "instance_external_ip" {
  value = google_compute_instance.flask_instance.network_interface.0.access_config.0.nat_ip
}

output "pubsub_topic" {
  value = google_pubsub_topic.flask_topic.id
}
