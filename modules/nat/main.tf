locals {
  public_subnets = {
    for subnet in var.public_subnets :
    subnet.az => subnet
  }

  nat_subnets = {
    for az in var.nat_azs :
    az => local.public_subnets[az]
  }
}

resource "aws_eip" "this" {
  for_each = local.nat_subnets

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-eip-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_subnets

  allocation_id = aws_eip.this[each.key].id
  subnet_id     = local.public_subnets[each.key].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })
}
