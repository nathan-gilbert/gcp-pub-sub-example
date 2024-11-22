# Variables
variable "project_id" {
  description = "The ID of the Google Cloud project."
  type        = string
}

variable "region" {
  description = "The region for the Google Cloud resources."
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "The zone for the Google Compute Engine instance."
  type        = string
  default     = "us-west1-a"
}

variable "instance_name" {
  description = "The name of the GCE instance."
  type        = string
  default     = "flask-app-instance"
}

variable "google_credentials" {
  description = "The path to the Google Cloud credentials file."
  type        = string
}
