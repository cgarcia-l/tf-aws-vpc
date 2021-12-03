################################################################################
# VPC
################################################################################
resource "aws_vpc" "this" {
  cidr_block                        = var.cidr
  instance_tenancy                  = var.instance_tenancy
  ipv4_ipam_pool_ids                = var.ipv4_ipam_pool_id
  enable_dns_hostnames              = var.enable_dns_hostnames
  enable_dns_support                = var.enable_dns_support
  enable_classiclink                = var.enable_classiclink
  enable_classiclink_dns_support    = var.enable_classiclink_dns_support
  assign_generated_ipv6_cidr_block  = var.assign_generated_ipv6_cidr_block

  tags = merge({ "Name" = format("%s", var.name) }, var.tags, var.vpc_tags)
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  vpc_id     = aws_vpc.this.id
  cidr_block = element(var.secondary_cidr_blocks, count.index)
  count      = length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = local.vpc_id
  tags   = merge({ "Name" = format("%s", var.name)}, var.tags, var.igw_tags)
}