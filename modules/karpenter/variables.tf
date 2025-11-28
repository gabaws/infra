variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "clusters" {
  description = "Mapa com informações dos clusters onde o Karpenter será instalado"
  type = map(object({
    cluster_name     = string
    cluster_location = string
    subnet_name      = string
    zones            = list(string)
  }))
}

variable "karpenter_namespace" {
  description = "Namespace onde o Karpenter será instalado"
  type        = string
  default     = "karpenter"
}

variable "karpenter_helm_repo" {
  description = "Repositório Helm do Karpenter para GCP. Para GCP"
  type        = string
  # Nota: O repositório exato pode variar. Consulte https://github.com/cloudpilot-ai/karpenter-provider-gcp
  # Por padrão, usamos o repositório oficial do Karpenter
  default = "oci://registry.k8s.io/karpenter"
}

variable "karpenter_version" {
  description = "Versão do Karpenter a ser instalada"
  type        = string
  default     = "v0.37.0"
}

variable "default_instance_types" {
  description = "Lista de tipos de instâncias padrão que o Karpenter pode usar"
  type        = list(string)
  default = [
    "e2-standard-2",
    "e2-standard-4",
    "e2-standard-8",
    "e2-highmem-2",
    "e2-highmem-4",
    "e2-highmem-8",
    "e2-highcpu-2",
    "e2-highcpu-4",
    "e2-highcpu-8"
  ]
}

variable "interruption_queue" {
  description = "Nome da fila SQS para interrupções (não usado no GCP, mas necessário para o Karpenter)"
  type        = string
  default     = ""
}

variable "additional_helm_values" {
  description = "Valores adicionais para o Helm chart do Karpenter"
  type        = map(string)
  default     = {}
}

