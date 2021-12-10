
################################################################################
# Provider
################################################################################

provider "aws" {
  region = local.region
}

################################################################################
# Locals
################################################################################

locals {
  region = "eu-west-1"
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source                         = "../"
  name                           = "vpc-test"
  cidr                           = "10.0.0.0/16"
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
  azs                            = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets                = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets                 = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  public_subnet_map = {
        public1 = [{ cidr_block = "10.0.4.0/24", availability_zone = "eu-west-1a" }],
        public2 = [{ cidr_block = "10.0.5.0/24", availability_zone = "eu-west-1b" }],
        public3 = [{ cidr_block = "10.0.6.0/24", availability_zone = "eu-west-1c" }]
  }
  private_subnet_map = {
        private1 = [{ cidr_block = "10.0.1.0/24", availability_zone = "eu-west-1a" }],
        private2 = [{ cidr_block = "10.0.2.0/24", availability_zone = "eu-west-1b" }],
        private3 = [{ cidr_block = "10.0.3.0/24", availability_zone = "eu-west-1c" }]
  }
  enable_nat_gateway             = true
  single_nat_gateway             = false
  one_nat_gateway_per_az         = true

}