output "vpc_id" {
  value = aws_vpc.this.id
}

output "igw_id" {
  value = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  value = { for name, subnet in aws_subnet.public : name => subnet.id }
}

output "private_subnet_ids" {
  value = { for name, subnet in aws_subnet.private : name => subnet.id }
}

output "data_subnet_ids" {
  value = { for name, subnet in aws_subnet.data : name => subnet.id }
}

output "route_table_ids" {
  value = {
    public  = aws_route_table.public.id
    private = { for name, rt in aws_route_table.private : name => rt.id }
    data    = aws_route_table.data.id
  }
}

output "private_route_table_ids" {
  value = {
    for name, subnet in aws_subnet.private :
    subnet.availability_zone => aws_route_table.private[name].id
  }
}
