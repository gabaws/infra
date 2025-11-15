variable "bootstrap_project_id" {
  description = "ID do projeto onde o bucket de estado será criado"
  type        = string
}

variable "bucket_name" {
  description = "Nome do bucket GCS que armazenará o estado do Terraform"
  type        = string
}

variable "bucket_location" {
  description = "Localização/região do bucket GCS"
  type        = string
  default     = "US"
}

variable "region" {
  description = "Região padrão usada pelo provider ao criar o bucket"
  type        = string
  default     = "us-central1"
}

