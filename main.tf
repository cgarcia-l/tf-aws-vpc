locals {
  vpc_id            = element(concat(aws_vpc_ipv4_cidr_block_association.this.*.vpc_id, aws_vpc.this.*.id, [""]), 0)
  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : length(var.private_subnets)
}

################################################################################
# VPC
################################################################################
resource "aws_vpc" "this" {
  cidr_block                        = var.cidr
  instance_tenancy                  = var.instance_tenancy
  ipv4_ipam_pool_id                = var.ipv4_ipam_pool_id
  enable_dns_hostnames              = var.enable_dns_hostnames
  enable_dns_support                = var.enable_dns_support
  enable_classiclink                = var.enable_classiclink
  enable_classiclink_dns_support    = var.enable_classiclink_dns_support
  assign_generated_ipv6_cidr_block  = var.assign_generated_ipv6_cidr_block

  tags = merge({ "Name" = format("%s", var.name) }, var.tags)
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  vpc_id     = aws_vpc.this.id
  cidr_block = element(var.secondary_cidr_blocks, count.index)
  count      = length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0
}

resource "aws_default_security_group" "this" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this.id

  dynamic "ingress" {
    for_each = var.default_security_group_ingress
    content {
      self             = lookup(ingress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(ingress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(ingress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(ingress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(ingress.value, "security_groups", "")))
      description      = lookup(ingress.value, "description", null)
      from_port        = lookup(ingress.value, "from_port", 0)
      to_port          = lookup(ingress.value, "to_port", 0)
      protocol         = lookup(ingress.value, "protocol", "-1")
    }
  }

  dynamic "egress" {
    for_each = var.default_security_group_egress
    content {
      self             = lookup(egress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(egress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(egress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(egress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(egress.value, "security_groups", "")))
      description      = lookup(egress.value, "description", null)
      from_port        = lookup(egress.value, "from_port", 0)
      to_port          = lookup(egress.value, "to_port", 0)
      protocol         = lookup(egress.value, "protocol", "-1")
    }
  }

  tags = merge({ "Name" = format("%s", var.default_security_group_name) }, var.tags)
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count  = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id
  tags   = merge({ "Name" = format("%s", var.name)}, var.tags)
}

################################################################################
# Public subnet
################################################################################

resource "aws_subnet" "public" {
  count = length(var.public_subnets) > 0 && (false == var.one_nat_gateway_per_az || length(var.public_subnets) >= length(var.azs)) ? length(var.public_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = element(concat(var.public_subnets, [""]), count.index)
  availability_zone               = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  map_public_ip_on_launch         = var.map_public_ip_on_launch
  assign_ipv6_address_on_creation = var.public_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.public_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.public_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, var.public_subnet_ipv6_prefixes[count.index]) : null

  tags = merge({ "Name" = format( "%s-${var.public_subnet_suffix}-%s", var.name, element(var.azs, count.index)) }, var.tags)
}

################################################################################
# Private subnet
################################################################################

resource "aws_subnet" "private" {
  count = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = var.private_subnets[count.index]
  availability_zone               = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  assign_ipv6_address_on_creation = var.private_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.private_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.private_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, var.private_subnet_ipv6_prefixes[count.index]) : null

  tags = merge({ "Name" = format( "%s-${var.private_subnet_suffix}-%s", var.name, element(var.azs, count.index)) }, var.tags)
}

################################################################################
# NAT Gateway
################################################################################
resource "aws_eip" "nat_gateway" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0

  vpc  = true
  tags = merge({ "Name" = format("natgw-%s-%s", var.name, element(var.azs, var.single_nat_gateway ? 0 : count.index)) }, var.tags)
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0

  allocation_id = element(aws_eip.nat_gateway.*.id, var.single_nat_gateway ? 0 : count.index)
  subnet_id     = element(aws_subnet.public.*.id, var.single_nat_gateway ? 0 : count.index)
  tags          = merge({ "Name" = format("%s-%s", var.name, element(var.azs, var.single_nat_gateway ? 0 : count.index)) }, var.tags)

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# Routes
################################################################################
resource "aws_route_table" "public" {
  count  = length(var.public_subnets) > 0 ? 1 : 0  

  vpc_id = local.vpc_id
  tags   = merge({ "Name" = format("%s-${var.public_subnet_suffix}", var.name) }, var.tags)
}

resource "aws_route" "public" {
  count                  = length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets) > 0 ? local.nat_gateway_count : 0

  vpc_id = local.vpc_id
  tags   = merge({ "Name" = var.single_nat_gateway ? "${var.name}-${var.private_subnet_suffix}" : format("%s-${var.private_subnet_suffix}-%s", var.name, element(var.azs, count.index)) }, var.tags)
}

resource "aws_route" "private" {
  count                  = var.enable_nat_gateway ? local.nat_gateway_count : 0

  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, var.single_nat_gateway ? 0 : count.index)
}
