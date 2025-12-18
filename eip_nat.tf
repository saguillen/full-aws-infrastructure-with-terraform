resource "aws_eip" "nat" {
  count = 2
  tags  = merge(var.tags, { Name = "${var.project}-eip-nat-${count.index}", Project = var.project })
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.project}-nat-${count.index}", Project = var.project })
}
