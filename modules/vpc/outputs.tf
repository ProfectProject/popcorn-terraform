output "vpc_id" {
  value = aws_vpc.this.id
}

output "igw_id" {
  value = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  value = { for name, subnet in aws_subnet.public : name => subnet.id }
}

output "app_subnet_ids" {
  value = { for name, subnet in aws_subnet.app : name => subnet.id }
}

output "data_subnet_ids" {
  value = { for name, subnet in aws_subnet.data : name => subnet.id }
}

output "route_table_ids" {
  value = {
    public = aws_route_table.public.id
    app    = { for name, rt in aws_route_table.app : name => rt.id }
    data   = aws_route_table.data.id
  }
}

output "private_route_table_ids" {
  value = {
    for name, subnet in aws_subnet.app :
    subnet.availability_zone => aws_route_table.app[name].id
  }
}
