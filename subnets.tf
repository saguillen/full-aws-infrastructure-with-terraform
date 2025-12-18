resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = element(local.azs, count.index)
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.project}-public-${element(local.azs, count.index)}", Project = var.project })
}

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 10 + count.index)
  availability_zone       = element(local.azs, count.index)
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.project}-private-${element(local.azs, count.index)}", Project = var.project })
}
