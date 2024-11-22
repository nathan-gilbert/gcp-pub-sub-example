# Flask App Receiving GCP Pub/Sub Push Notifications

_NOTE: This is not a production hardened service. Use at your own risk._

## Setup

- `tofu apply`
- Log in via GCP SSH connection to view logs or use Log Viewer in GCP dashboard

## Testing

Get request: `curl -k <https://35.247.30.56:8080/>`
Simulated Push Notification:

```bash

curl -k -X POST -H "Content-Type: application/json" \
  -d '{"message":{"data":"SGVsbG8sIFdvcmxkIQ==","attributes":{"key":"value"}}}' \
  http://35.247.30.56:8080/pubsub

```

Note: GCP Pub/Sub doesn't accept a self signed certificate. To get the full push experience you'll
need to acquire an actual trusted certificate. Otherwise simulate it above.
