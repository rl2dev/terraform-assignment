provider "aws" {
  region = var.aws_region
}

###############################
######## INTERNET VPC #########
###############################
module "internet_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.internet_vpc_name
  cidr = var.internet_vpc_cidr

  azs                  = var.internet_vpc_azs
  public_subnets        = var.internet_vpc_public_subnets
  public_subnet_names   = var.internet_vpc_public_subnet_names
  private_subnets       = var.internet_vpc_private_subnets
  private_subnet_names  = var.internet_vpc_private_subnet_names

  enable_nat_gateway = var.internet_vpc_enable_nat_gateway
  single_nat_gateway = var.internet_vpc_single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true
}

###############################
######## WORKLOAD VPC #########
###############################
module "workload_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.workload_vpc_name
  cidr = var.workload_vpc_cidr

  azs                   = var.workload_vpc_azs
  private_subnets       = var.workload_vpc_private_subnets
  private_subnet_names  = var.workload_vpc_private_subnet_names
  database_subnets      = var.workload_vpc_database_subnets
  database_subnet_names = var.workload_vpc_database_subnet_names

  enable_nat_gateway = var.workload_vpc_enable_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true
}

###############################
####### TRANSIT GATEWAY #######
###############################
module "transit_gateway" {
  source = "./modules/transit_gateway"

  internet_vpc_id                      = module.internet_vpc.vpc_id
  internet_vpc_private_subnet_ids      = module.internet_vpc.private_subnets
  internet_vpc_public_route_table_ids  = module.internet_vpc.public_route_table_ids
  workload_vpc_id                      = module.workload_vpc.vpc_id
  workload_vpc_cidr                    = module.workload_vpc.vpc_cidr_block
  workload_vpc_private_subnet_ids      = module.workload_vpc.private_subnets
  workload_vpc_private_route_table_ids = module.workload_vpc.private_route_table_ids
}

###############################
########## WEB NLB ############
###############################
module "web_nlb" {
  source = "./modules/web_nlb"

  vpc_id             = module.workload_vpc.vpc_id
  private_subnet_ids = module.workload_vpc.private_subnets
  nlb_name           = var.web_nlb_name
}

###############################
########## WEB ALB ############
###############################
module "web_alb" {
  source = "./modules/web_alb"

  vpc_id             = module.workload_vpc.vpc_id
  private_subnet_ids = module.workload_vpc.private_subnets
  nlb_tg_arn         = module.web_nlb.nlb_tg_arn
}

###############################
####### GATEWAY ALB ###########
###############################
module "gateway_alb" {
  source = "./modules/gateway_alb"

  internet_vpc_id                  = module.internet_vpc.vpc_id
  internet_public_subnet_ids       = module.internet_vpc.public_subnets
  workload_vpc_private_subnet_ids  = slice(module.workload_vpc.private_subnets, 0, 2)
  workload_nlb_name                = module.web_nlb.nlb_name
}

###############################
########## ECS ###############
###############################
module "ecs" {
  source = "./modules/ecs"

  vpc_id                          = module.workload_vpc.vpc_id
  app_subnet_ids                  = [module.workload_vpc.private_subnets[3], module.workload_vpc.private_subnets[4]]
  workload_alb_target_group_arn   = module.web_alb.alb_target_group_arn
  workload_alb_security_group_id  = module.web_alb.alb_security_group_id
  aws_region                      = var.aws_region
}
