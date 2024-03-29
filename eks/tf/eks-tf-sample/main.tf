provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.25.0"

  cluster_name    = local.name

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # EKS CONTROL PLANE VARIABLES
  cluster_version = local.cluster_version

  # List of Additional roles admin in the cluster
  # Comment this section if you ARE NOT at an AWS Event, as the TeamRole won't exist on your site, or replace with any valid role you want
  # map_roles = [
  #   {
  #     rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/TeamRole"
  #     username = "ops-role" # The user name within Kubernetes to map to the IAM role
  #     groups   = ["system:masters"] # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
  #   }
  # ]

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mng1 = {
      node_group_name = local.node_group_name
      instance_types  = ["m5.large"]
      subnet_ids      = module.vpc.private_subnets
      min_size     = 1
      max_size     = 10
      desired_size = 3
      disk_size    = 100 # disk_size will be ignored when using Launch Templates
    }
  }

  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.25.0"

  eks_cluster_id                    = module.eks_blueprints.eks_cluster_id

  # EKS Addons

  # enable_amazon_eks_aws_ebs_csi_driver  = true
  enable_amazon_eks_coredns             = true
  enable_amazon_eks_kube_proxy          = true
  enable_amazon_eks_vpc_cni             = true

  #K8s Add-ons
  # enable_argocd                        = true
  # enable_aws_for_fluentbit             = true
  enable_aws_load_balancer_controller  = true
  # enable_cluster_autoscaler            = true
  # enable_metrics_server                = true
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = local.name
  cidr = local.vpc_cidr

  azs  = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 5, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 5, k + 10)]

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }  

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = "1"
  }

    tags = local.tags
}
