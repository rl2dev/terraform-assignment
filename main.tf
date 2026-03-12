provider "aws" {
  region = "ap-southeast-1"
}

###############################
######## INTERNET VPC #########
###############################
module "internet_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "internet-vpc"
  cidr = "10.0.0.0/16"

  azs                  = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnets        = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_names   = ["gateway-subnet-a", "gateway-subnet-b"]
  private_subnets       = ["10.0.3.0/24", "10.0.4.0/24"]
  private_subnet_names  = ["internet-tgw-subnet", "internet-firewall-subnet"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true
}

###############################
######## WORKLOAD VPC #########
###############################
module "workload_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "workload-vpc"
  cidr = "10.1.0.0/16"

  azs                   = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c", "ap-southeast-1a", "ap-southeast-1b"]
  private_subnets       = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24", "10.1.4.0/24", "10.1.5.0/24"]
  private_subnet_names  = ["workload-web-subnet-a", "workload-web-subnet-b", "workload-tgw-subnet", "workload-app-subnet-a", "workload-app-subnet-b"]
  database_subnets      = ["10.1.6.0/24", "10.1.7.0/24"]
  database_subnet_names = ["workload-db-subnet-a", "workload-db-subnet-b"]

  enable_nat_gateway = false

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
  nlb_name           = "workload-vpc-nlb"
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
  aws_region                      = "ap-southeast-1"
}
