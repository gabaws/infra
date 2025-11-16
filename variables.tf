variable "project_id" {
  description = "ID do projeto GCP que será usado (projeto existente)"
  type        = string
  default     = "infra-474223"
}

variable "region" {
  description = "Região padrão onde os recursos serão provisionados"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Nome da rede VPC"
  type        = string
  default     = "main-vpc"
}

variable "manage_network" {
  description = "Quando false, reaproveita uma VPC existente em vez de criar outra"
  type        = bool
  default     = true
}

variable "subnets" {
  description = "Lista de sub-redes que serão criadas"
  type = list(object({
    name          = string
    ip_cidr_range = string
    region        = string
    description   = optional(string)
  }))
  default = [
    {
      name          = "subnet-us-central1"
      ip_cidr_range = "10.0.1.0/24"
      region        = "us-central1"
      description   = "Subnet para a região us-central1"
    },
    {
      name          = "subnet-us-east1"
      ip_cidr_range = "10.0.2.0/24"
      region        = "us-east1"
      description   = "Subnet para a região us-east1"
    }
  ]
}

variable "secondary_ranges" {
  description = "Faixas secundárias de IP usadas pelos pods e serviços do GKE"
  type = map(list(object({
    range_name    = string
    ip_cidr_range = string
  })))
  default = {
    "subnet-us-central1" = [
      {
        range_name    = "pods"
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = "services"
        ip_cidr_range = "10.2.0.0/20"
      }
    ]
    "subnet-us-east1" = [
      {
        range_name    = "pods"
        ip_cidr_range = "10.3.0.0/16"
      },
      {
        range_name    = "services"
        ip_cidr_range = "10.4.0.0/20"
      }
    ]
  }
}

variable "primary_cluster_name" {
  description = "Nome lógico do cluster principal (receberá ArgoCD e fluxos de orquestração)"
  type        = string
  default     = "master-engine"
}

variable "secondary_cluster_name" {
  description = "Nome lógico do segundo cluster (foco em workloads de aplicação)"
  type        = string
  default     = "app-engine"
}

variable "argocd_target_cluster" {
  description = "Nome do cluster onde o ArgoCD será instalado"
  type        = string
  default     = "master-engine"
}

variable "gke_clusters" {
  description = "Mapa com as configurações de cada cluster GKE"
  type = map(object({
    region                  = string
    zone                    = string
    initial_node_count      = number
    min_node_count          = number
    max_node_count          = number
    machine_type            = string
    disk_size_gb            = number
    enable_private_nodes    = bool
    enable_private_endpoint = bool
    master_authorized_networks = optional(list(object({
      cidr_block   = string
      display_name = string
    })), [])
  }))
  default = {
    master-engine = {
      region                     = "us-central1"
      zone                       = "us-central1-a"
      initial_node_count         = 1
      min_node_count             = 1
      max_node_count             = 5
      machine_type               = "e2-medium"
      disk_size_gb               = 50
      enable_private_nodes       = true
      enable_private_endpoint    = false
      master_authorized_networks = []
    }
    app-engine = {
      region                     = "us-east1"
      zone                       = "us-east1-b"
      initial_node_count         = 1
      min_node_count             = 1
      max_node_count             = 5
      machine_type               = "e2-medium"
      disk_size_gb               = 50
      enable_private_nodes       = true
      enable_private_endpoint    = false
      master_authorized_networks = []
    }
  }
}

variable "enable_cluster_addons" {
  description = "Quando true, instala os add-ons Kubernetes (Istio/ASM, gateways e ArgoCD). Requer clusters já acessíveis."
  type        = bool
  default     = false
}

variable "istio_namespace" {
  description = "Namespace onde o Istio/ASM será instalado"
  type        = string
  default     = "istio-system"
}

variable "manage_istio_namespace" {
  description = "Quando true, o Terraform cria/atualiza o namespace do Istio antes dos charts. Defina como false se o namespace já é gerenciado por outro processo (ex.: Anthos Service Mesh)."
  type        = bool
  default     = false
}

variable "gateway_namespace" {
  description = "Namespace dedicado ao gateway (deixe vazio para usar o mesmo do Istio)"
  type        = string
  default     = ""
}

variable "asm_revision" {
  description = "Revisão do ASM/Istio aplicada nas labels (ex.: asm-managed)"
  type        = string
  default     = "asm-managed"
}

variable "istio_chart_version" {
  description = "Versão das charts oficiais do Istio/ASM a serem instaladas"
  type        = string
  default     = "1.21.1"
}

variable "istio_repository" {
  description = "Repositório Helm com as charts do Istio/ASM"
  type        = string
  default     = "https://istio-release.storage.googleapis.com/charts"
}

variable "istio_gateway_chart" {
  description = "Nome do chart Helm usado para instalar o gateway"
  type        = string
  default     = "gateway"
}

variable "install_gateway" {
  description = "Controla a instalação do Istio Ingress Gateway"
  type        = bool
  default     = true
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
  description = "Labels adicionais aplicadas ao deployment do gateway"
  type        = map(string)
  default     = {}
}

variable "istiod_values" {
  description = "Valores adicionais para o chart Helm do istiod"
  type        = map(any)
  default     = {}
}

variable "istio_gateway_values" {
  description = "Valores adicionais para o chart Helm do gateway"
  type        = map(any)
  default     = {}
}

variable "install_argocd" {
  description = "Controla a instalação do ArgoCD em cada cluster"
  type        = bool
  default     = true
}

variable "argocd_namespace" {
  description = "Namespace onde o ArgoCD será instalado"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Versão do chart Helm do ArgoCD"
  type        = string
  default     = "7.3.6"
}

variable "argocd_chart" {
  description = "Nome do chart Helm do ArgoCD"
  type        = string
  default     = "argo-cd"
}

variable "argocd_repository" {
  description = "Repositório Helm utilizado para instalar o ArgoCD"
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argocd_values" {
  description = "Valores adicionais para o chart Helm do ArgoCD"
  type        = map(any)
  default     = {}
}

variable "helm_release_timeout" {
  description = "Tempo (em segundos) para aguardar a conclusão de cada helm_release"
  type        = number
  default     = 900
}

variable "helm_wait" {
  description = "Controla se o Terraform deve aguardar o Helm concluir o rollout (wait). Desative em clusters lentos para evitar timeout."
  type        = bool
  default     = false
}

