## Pass scenario including "google_notebooks_runtime" conditions

# Required Google APIs
locals {
  googleapis = ["notebooks.googleapis.com", "compute.googleapis.com", "servicenetworking.googleapis.com", "aiplatform.googleapis.com", ]
}

# Enable required services
resource "google_project_service" "apis" {
  for_each           = toset(local.googleapis)
  project            = "modular-scout-345114"
  service            = each.key
  disable_on_destroy = false
}

# Get project information

data "google_project" "project" {
  project_id = "modular-scout-345114"
}

# output block to get the project number
output "number" {
  value = data.google_project.project.number
}

# Creation of Custom Service Account
resource "google_service_account" "custom_sa" {
  account_id   = "custom-sa17"
  display_name = "Custom Service Account"
  project      = var.project_id
}

# Creation of key_ring
resource "google_kms_key_ring" "example-keyring" {
  name     = "keyring-example1016"
  location = "us-central1"
  depends_on = [
    google_project_service.apis
  ]
}

# Creation of kms_crypto_key
resource "google_kms_crypto_key" "secrets" {
  name     = "key1016"
  key_ring = google_kms_key_ring.example-keyring.id
}

# Adding members to kms_crypto_key with roles
resource "google_kms_crypto_key_iam_member" "crypto_key" {
  crypto_key_id = google_kms_crypto_key.secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.custom_sa.email}"
}

# Adding members to kms_crypto_key with roles
resource "google_kms_crypto_key_iam_member" "service_identity_compute_iam_crypto_key" {
  crypto_key_id = google_kms_crypto_key.secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@compute-system.iam.gserviceaccount.com"
}

# creation of notebooks_instance
resource "google_notebooks_instance" "instance" {
  project         = data.google_project.project.project_id
  name            = "notebook-instance18"
  location        = "us-central1-a"
  service_account = google_service_account.custom_sa.email
  no_public_ip    = true
  no_proxy_access = false
  disk_encryption = "CMEK"
  kms_key         = google_kms_crypto_key.secrets.id
  machine_type    = "e2-medium"

  metadata = {
    proxy-mode = "service_account"

  }
  container_image {
    repository = "gcr.io/deeplearning-platform-release/base-cpu"
    tag        = "latest"
  }
}

# Role for Managed notebooks_runtime Instances
resource "google_project_iam_member" "notebooks_runner" {
  project = data.google_project.project.project_id
  role    = "roles/notebooks.runner"
  member  = "serviceAccount:${google_service_account.custom_sa.email}"
}

# Roles for Notebook Service Agents
# Dependency: The Notebook Service Agent must have access to the CMEK and the network used during instance creation.

resource "google_project_service_identity" "notebooks_identity" {
  provider = google-beta
  project  = data.google_project.project.project_id
  service  = "notebooks.googleapis.com"
}

# Adding roles to Notebook Service Agents service account
resource "google_kms_crypto_key_iam_member" "service_identity_iam_crypto_key" {
  crypto_key_id = google_kms_crypto_key.secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.notebooks_identity.email}"
}

# Creating google_notebooks_runtime resource
resource "google_notebooks_runtime" "managed" {
  project  = data.google_project.project.project_id
  name     = "notebooks-runtime-02"
  location = "us-central1"
  access_config {
    access_type   = "SERVICE_ACCOUNT"
    runtime_owner = google_service_account.custom_sa.email
  }
  virtual_machine {
    virtual_machine_config {
      machine_type     = "n1-standard-4"
      internal_ip_only = true
      data_disk {
        initialize_params {
          disk_size_gb = "100"
          disk_type    = "PD_STANDARD"
        }
      }
      encryption_config {
        kms_key = google_kms_crypto_key.secrets.id
      }
    }
  }
}  