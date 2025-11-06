terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ------------------------------------------------------------
# 1️⃣  Firestore (Native mode)
# ------------------------------------------------------------
resource "google_firestore_database" "default" {
  name   = "(default)"
  project = var.project_id
  location_id = var.region
  type = "FIRESTORE_NATIVE"
}

# ------------------------------------------------------------
# 2️⃣  GCS bucket for uploaded files
# ------------------------------------------------------------
resource "google_storage_bucket" "uploads_bucket" {
  name                        = "gen2-uploads"
  location                    = var.region
  uniform_bucket_level_access  = true
  force_destroy                = true
}

# ------------------------------------------------------------
# 3️⃣  GCS bucket for function source ZIP
# ------------------------------------------------------------
resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-fn-src-${var.region}"
  location = var.region
  force_destroy = true
}

# ------------------------------------------------------------
# 4️⃣  Package and upload ZIP
# ------------------------------------------------------------
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/function.zip"
}

resource "google_storage_bucket_object" "function_source" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_zip.output_path
}

# ------------------------------------------------------------
# 5️⃣  Cloud Function (Gen 2)
# ------------------------------------------------------------
resource "google_cloudfunctions2_function" "upload_file_function" {
  name        = "upload-file-zip-fn"
  location    = var.region
  description = "Uploads file to GCS and stores metadata in Firestore"

  build_config {
    runtime     = "python312"
    entry_point = "upload_file"

    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_source.name
      }
    }


  }

  service_config {
    min_instance_count  = 0
    max_instance_count  = 1
    available_memory    = "256M"
    timeout_seconds     = 60
    ingress_settings    = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
    environment_variables = {
      BUCKET_NAME     = "gen2-uploads"
      DATABASE_ID     = "(default)"
      COLLECTION_NAME = "uploads"
    }
  }

}

# ------------------------------------------------------------
# 6️⃣  Allow public invocation
# ------------------------------------------------------------


resource "google_cloud_run_service_iam_member" "public_invoker" {
  location = google_cloudfunctions2_function.upload_file_function.location
  service  = google_cloudfunctions2_function.upload_file_function.service_config[0].service
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ------------------------------------------------------------
# 7️⃣  IAM permissions for the function’s service account
# ------------------------------------------------------------
data "google_project" "current" {}

resource "google_project_iam_member" "fn_storage_access" {
  project = data.google_project.current.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_cloudfunctions2_function.upload_file_function.service_config[0].service_account_email}"
}

resource "google_project_iam_member" "fn_firestore_access" {
  project = data.google_project.current.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_cloudfunctions2_function.upload_file_function.service_config[0].service_account_email}"
}

# ------------------------------------------------------------
# 8️⃣  Artifact Registry Repository
# ------------------------------------------------------------
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "cloud-functions"
  description   = "Docker repository for Cloud Functions"
  format        = "DOCKER"
}

# ------------------------------------------------------------
# 9️⃣  Container-based Cloud Function
# ------------------------------------------------------------
resource "google_cloudfunctions2_function" "container_function" {
  name        = "container-function"
  location    = var.region
  description = "Cloud Function with container image"

  build_config {
    runtime     = "python312"
    entry_point = "handle_request"

    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    min_instance_count = 0
    max_instance_count = 2
    available_memory   = "512M"
    timeout_seconds    = 120
    ingress_settings   = "ALLOW_ALL"

    environment_variables = {
      BUCKET_NAME     = "gen2-uploads"
      DATABASE_ID     = "(default)"
      COLLECTION_NAME = "uploads"
    }
  }
}

# ------------------------------------------------------------
# 🔟  IAM for Container Function
# ------------------------------------------------------------
resource "google_cloud_run_service_iam_member" "container_function_invoker" {
  location = google_cloudfunctions2_function.container_function.location
  service  = google_cloudfunctions2_function.container_function.service_config[0].service
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ------------------------------------------------------------
# ⭐️  Outputs
# ------------------------------------------------------------
output "function_url" {
  description = "Deployed Cloud Function URL"
  value       = google_cloudfunctions2_function.upload_file_function.service_config[0].uri
}

output "container_function_url" {
  description = "Deployed Container Cloud Function URL"
  value       = google_cloudfunctions2_function.container_function.service_config[0].uri
}

output "uploads_bucket" {
  description = "Bucket used for uploaded files"
  value       = google_storage_bucket.uploads_bucket.name
}

output "firestore_database" {
  description = "Firestore database ID"
  value       = google_firestore_database.default.name
}

output "artifact_registry_repo" {
  description = "Artifact Registry Repository"
  value       = google_artifact_registry_repository.docker_repo.name
}

