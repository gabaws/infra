variable "project_id" {
  description = "ID do projeto GCP onde o bucket será criado"
  type        = string
}

variable "bucket_name" {
  description = "Nome do bucket GCS que armazenará o estado do Terraform"
  type        = string
}

variable "bucket_location" {
  description = "Localização do bucket GCS"
  type        = string
  default     = "US"
}

variable "force_destroy" {
  description = "Quando true, remove todos os objetos ao destruir o bucket"
  type        = bool
  default     = false
}

variable "num_newer_versions" {
  description = "Quantidade de versões que devem ser mantidas para os arquivos de estado"
  type        = number
  default     = 5
}

variable "kms_key_name" {
  description = "Nome da chave KMS usada na criptografia do bucket (opcional)"
  type        = string
  default     = null
}

variable "admins" {
  description = "Lista de membros IAM com acesso administrativo ao bucket"
  type        = list(string)
  default     = []
}

variable "readers" {
  description = "Lista de membros IAM com acesso somente leitura ao bucket"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels aplicadas ao bucket"
  type        = map(string)
  default = {
    managed-by = "terraform"
    purpose    = "terraform-state"
  }
}

