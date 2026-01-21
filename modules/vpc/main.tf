locals {
  public_subnets = { for subnet in var.public_subnets : subnet.name => subnet }
  app_subnets    = { for subnet in var.app_subnets : subnet.name => subnet }
  data_subnets   = { for subnet in var.data_subnets : subnet.name => subnet }
  base_tags      = merge({ Name = var.name }, var.tags)
  public_subnets_by_az = {
    for subnet in var.public_subnets :
    subnet.az => subnet
  }
  nat_azs = var.enable_nat ? (
    var.single_nat_gateway ? [sort(keys(local.public_subnets_by_az))[0]] : sort(keys(local.public_subnets_by_az))
  ) : []
  nat_subnets = {
    for az in local.nat_azs :
    az => local.public_subnets_by_az[az]
  }
  app_route_table_by_az = {
    for name, subnet in local.app_subnets :
    subnet.az => name
  }
  app_route_table_ids = {
    for az, name in local.app_route_table_by_az :
    az => aws_route_table.app[name].id
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.base_tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = each.value.name
    Tier = "public"
  })
}

resource "aws_subnet" "app" {
  for_each          = local.app_subnets
  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = merge(var.tags, {
    Name = each.value.name
    Tier = "app"
  })
}

resource "aws_subnet" "data" {
  for_each          = local.data_subnets
  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = merge(var.tags, {
    Name = each.value.name
    Tier = "data"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-public" })
}

resource "aws_route_table" "app" {
  for_each = local.app_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rt-app-${each.value.az}"
  })
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-data" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_eip" "nat" {
  for_each = local.nat_subnets

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-eip-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[local.nat_subnets[each.key].name].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })
}

resource "aws_route" "app_nat" {
  for_each = var.enable_nat ? (
    var.single_nat_gateway ? local.app_route_table_ids : {
      for az, rt_id in local.app_route_table_ids :
      az => rt_id
      if contains(keys(aws_nat_gateway.this), az)
    }
  ) : {}

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = var.single_nat_gateway ? (
    aws_nat_gateway.this[local.nat_azs[0]].id
  ) : aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "data" {
  for_each       = aws_subnet.data
  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}
