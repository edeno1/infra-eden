module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "test-cluster"
  cluster_version = "1.29"
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni = { most_recent = true }
  }

  vpc_id     = aws_vpc.front_vpc.id
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  eks_managed_node_group_defaults = {
    instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
  }

  eks_managed_node_groups = {
    blue = {}
    green = {
      min_size     = 1
      max_size     = 10
      desired_size = 1
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
    }
  }

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::096432477737:role/AWSReservedSSO_AdministratorAccess_1ddd114f3e646279"
      username = "admin"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::096432477737:user/interview_user"
      username = "interview_user"
      groups   = ["system:masters"]
    }
  ]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "load-balancer-controller-dev"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["lb:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_namespace" "aws_load_balancer_namespace" {
  metadata {
    name = "lb"
  }
}

resource "kubernetes_namespace" "processing_namespace" {
  metadata {
    name = "processing"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "lb"
  force_update = true
  version    = "1.7.0"

  set {
    name  = "replicaCount"
    value = "2"
  }
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "vpcId"
    value = aws_vpc.front_vpc.id
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.load_balancer_controller_irsa_role.iam_role_arn
  }
  set {
    name  = "defaultSslPolicy"
    value = "ELBSecurityPolicy-TLS13-1-3-2021-06"
  }
}
resource "aws_cloudfront_distribution" "app_distribution" {
  origin {
    domain_name = "k8s-default-hellowor-a27ab4cdfe-576779226.eu-west-1.elb.amazonaws.com"
    origin_id   = "myALBOrigin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true
  is_ipv6_enabled = true
  comment = "CloudFront Distribution for Kubernetes application using HTTP only"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "myALBOrigin"

    forwarded_values {
      query_string = true  # Forward all query strings to the origin

      cookies {
        forward = "all"  # Forward all cookies to the origin
      }
    }

    viewer_protocol_policy = "redirect-to-https"  # Redirect HTTP requests to HTTPS
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true  # Using CloudFront's default certificate
  }
  web_acl_id = "arn:aws:wafv2:us-east-1:096432477737:global/webacl/CreatedByCloudFront-740c2040-a0cb-41e2-8f1f-55dd250c2575/5d4c6bc5-b5db-4aaa-89b9-397d405570b0"
}
