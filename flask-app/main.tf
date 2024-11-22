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
      //image = "ubuntu-os-cloud/ubuntu-2204-lts"
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
    apt update
    apt install -y python3-flask python3-gunicorn
    openssl req -x509 -newkey rsa:4096 -keyout /opt/key.pem -out /opt/cert.pem -days 365 -nodes -subj "/CN=flask-app"

    cat <<EOF > /opt/app.py
    import base64
    import logging
    from flask import Flask, request, jsonify

    # Configure logging
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler("/opt/app.log"),  # Log to a file
            logging.StreamHandler()         # Log to the console
        ]
    )

    logger = logging.getLogger()

    app = Flask(__name__)

    @app.route('/pubsub', methods=['POST'])
    def pubsub_push():
      try:
          # Verify the request comes from Pub/Sub
          envelope = request.get_json()
          logger.info("Received Pub/Sub message.")
          if not envelope:
              return jsonify({"error": "Invalid request"}), 400

          # Parse the Pub/Sub message
          message = envelope.get("message")
          if not message:
              return jsonify({"error": "Missing message"}), 400

          # Decode the message data
          data = base64.b64decode(message.get("data")).decode("utf-8")
          attributes = message.get("attributes", {})
          message_id = message.get("messageId")
          publish_time = message.get("publishTime")

          # Log the message for debugging
          logger.info(f"Received message: {data}")
          logger.info(f"Attributes: {attributes}")
          logger.info(f"Message ID: {message_id}, Published at: {publish_time}")

          return jsonify({"status": "success"}), 200
      except Exception as e:
          logger.info(f"Error processing request: {e}")
          return jsonify({"error": "Internal server error"}), 500

    @app.route("/", methods=["GET"])
    def default_route():
        """Default route for GET requests."""
        logger.info("Received a GET request")
        return jsonify({"message": "Flask app is running and ready to receive Pub/Sub messages!"}), 200

    if __name__ == "__main__":
        # Start the Flask app with SSL context for HTTPS
        app.run(host="0.0.0.0", port=8080)
    EOF

    cat <<EOF > /etc/systemd/system/flask-app.service
    [Unit]
    Description=Flask App

    [Service]
    WorkingDirectory=/opt
    ExecStart=/usr/bin/python3 -m gunicorn -b 0.0.0.0:8080 --certfile=/opt/cert.pem --keyfile=/opt/key.pem app:app
    Restart=always
    User=root
    Group=root

    [Install]
    WantedBy=multi-user.target
    EOF

    systemctl daemon-reload
    systemctl start flask-app.service
    systemctl enable flask-app.service
  EOT
}

resource "google_compute_firewall" "allow_flask" {
  name    = "allow-flask"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"] # Allow access from any IP (use cautiously).
}


resource "google_pubsub_topic" "flask_topic" {
  name = "flask-app-topic"
}

resource "google_pubsub_subscription" "flask_subscription" {
  name  = "flask-app-subscription"
  topic = google_pubsub_topic.flask_topic.id

  push_config {
    push_endpoint = "https://${google_compute_instance.flask_instance.network_interface.0.access_config.0.nat_ip}:8080/pubsub"
  }
}

output "instance_external_ip" {
  value = google_compute_instance.flask_instance.network_interface.0.access_config.0.nat_ip
}

output "pubsub_topic" {
  value = google_pubsub_topic.flask_topic.id
}
