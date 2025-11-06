variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "gcppoc-477305"
}

variable "region" {
  description = "GCP region for deployment"
  type        = string
  default     = "asia-south1"
}

variable "bucket_name" {
  description = "Target GCS bucket for uploaded files"
  type        = string
  default = "gen2-uploads"
}

variable "collection_name" {
  description = "Firestore collection name for metadata"
  type        = string
  default     = "uploads"
}
