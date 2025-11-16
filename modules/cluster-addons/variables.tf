variable "cluster_name" {
  description = "Nome do cluster onde os addons serão instalados"
  type        = string
}

variable "istio_namespace" {
  description = "Namespace onde o Istio será instalado"
  type        = string
  default     = "istio-system"
}

variable "manage_istio_namespace" {
  description = "Quando true, o módulo cria/atualiza o namespace do Istio antes dos charts"
  type        = bool
  default     = true
}

variable "asm_revision" {
  description = "Revisão do ASM/Istio a ser aplicada (ex.: asm-managed)"
  type        = string
  default     = "asm-managed"
}

variable "istio_repository" {
  description = "Repositório Helm do Istio/ASM"
  type        = string
  default     = "https://istio-release.storage.googleapis.com/charts"
}

variable "istio_chart_version" {
  description = "Versão das charts do Istio"
  type        = string
}

variable "istio_gateway_chart" {
  description = "Nome do chart Helm utilizado para o gateway"
  type        = string
  default     = "gateway"
}

variable "install_gateway" {
  description = "Controle para instalar o gateway de entrada"
  type        = bool
  default     = true
}

variable "gateway_namespace" {
  description = "Namespace dedicado ao gateway (vazio usa o mesmo namespace do Istio)"
  type        = string
  default     = ""
}

variable "additional_istio_namespace_labels" {
  description = "Labels adicionais para o namespace do Istio"
  type        = map(string)
  default     = {}
}

variable "gateway_namespace_labels" {
  description = "Labels adicionais para o namespace do gateway"
  type        = map(string)
  default     = {}
}

variable "gateway_labels" {
  description = "Labels adicionais para o deployment do gateway"
  type        = map(string)
  default     = {}
}

variable "istiod_values" {
  description = "Valores adicionais para o chart do istiod"
  type        = map(any)
  default     = {}
}

variable "istio_gateway_values" {
  description = "Valores adicionais para o chart do gateway"
  type        = map(any)
  default     = {}
}

variable "install_argocd" {
  description = "Controle para instalar o ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_repository" {
  description = "Repositório Helm do ArgoCD"
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argocd_chart" {
  description = "Nome do chart Helm do ArgoCD"
  type        = string
  default     = "argo-cd"
}

variable "argocd_chart_version" {
  description = "Versão do chart do ArgoCD"
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace onde o ArgoCD será instalado"
  type        = string
  default     = "argocd"
}

variable "argocd_values" {
  description = "Valores adicionais para o chart do ArgoCD"
  type        = map(any)
  default     = {}
}

variable "helm_release_timeout" {
  description = "Tempo (em segundos) aguardado nas instalações Helm"
  type        = number
  default     = 900
}

variable "helm_wait" {
  description = "Controla se o Helm deve aguardar o rollout completo (wait)"
  type        = bool
  default     = false
}
