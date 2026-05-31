provider "aws" {
  region = var.aws_region
}

provider "random" {
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-subnet-2" }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${var.project_name}-private-subnet-1" }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}c"
  tags              = { Name = "${var.project_name}-private-subnet-2" }
}

resource "aws_subnet" "db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${var.project_name}-db-subnet-1" }
}

resource "aws_subnet" "db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "${var.aws_region}c"
  tags              = { Name = "${var.project_name}-db-subnet-2" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id     = aws_eip.nat.id
  connectivity_type = "public"
  availability_mode = "regional"
  vpc_id            = aws_vpc.main.id
  tags              = { Name = "${var.project_name}-nat" }
  depends_on        = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_1" {
  subnet_id      = aws_subnet.db_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_2" {
  subnet_id      = aws_subnet.db_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_security_group" "web" {
  name   = "${var.project_name}-web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip, var.instance_connect_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-web-sg" }
}

resource "aws_security_group" "app" {
  name   = "${var.project_name}-app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

resource "aws_security_group" "db" {
  name   = "${var.project_name}-db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-db-sg" }
}

resource "aws_security_group" "bastion" {
  name   = "${var.project_name}-bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip, var.instance_connect_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-bastion-sg" }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.db_1.id, aws_subnet.db_2.id]

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "ecommerce"
  username               = "admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
  multi_az               = false

  tags = { Name = "${var.project_name}-db" }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "web_1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_pair_name
  user_data              = file("${path.module}/userdata/web_server.sh")
  iam_instance_profile   = aws_iam_instance_profile.web.name

  tags = { Name = "${var.project_name}-web-1" }
}

resource "aws_instance" "web_2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_pair_name
  user_data              = file("${path.module}/userdata/web_server.sh")
  iam_instance_profile   = aws_iam_instance_profile.web.name

  tags = { Name = "${var.project_name}-web-2" }
}

resource "aws_instance" "app_1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.app.name
  user_data = templatefile("${path.module}/userdata/app_server.sh", { 
    db_host       = aws_db_instance.main.address
    db_password   = var.db_password
    sns_topic_arn = aws_sns_topic.main.arn
    aws_region    = var.aws_region
  })

  tags = { Name = "${var.project_name}-app-1" }
}

resource "aws_instance" "app_2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_2.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.app.name
  user_data = templatefile("${path.module}/userdata/app_server.sh", { 
    db_host       = aws_db_instance.main.address
    db_password   = var.db_password
    sns_topic_arn = aws_sns_topic.main.arn
    aws_region    = var.aws_region
  })

  tags = { Name = "${var.project_name}-app-2" }
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  tags = { Name = "${var.project_name}-lb-target-group" }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_target_group_attachment" "web_1" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.web_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_2" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.web_2.id
  port             = 80
}

resource "aws_sns_topic" "main" {
  name = "${var.project_name}-sns"

  tags = { Name = "${var.project_name}-sns" }
}

resource "aws_sns_topic_subscription" "main" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = var.subscriber_email
}

resource "aws_iam_role" "app" {
  name = "${var.project_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "app" {
  name = "${var.project_name}-app-policy"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.main.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app.name
}

resource "aws_ec2_instance_connect_endpoint" "main" {
  subnet_id          = aws_subnet.private_1.id
  security_group_ids = [aws_security_group.bastion.id]

  tags = { Name = "${var.project_name}-eice" }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_acm_certificate" "main" {
  provider = aws.us_east_1
  domain   = "*.kevinlutes.com"
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_distribution" "main" {
  enabled = true
  aliases = ["shop.kevinlutes.com"]

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.main.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Name = "${var.project_name}-cloudfront" }
}

data "aws_route53_zone" "main" {
  name = "kevinlutes.com"
}

resource "aws_route53_record" "shop" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "shop.kevinlutes.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_iam_role" "web" {
  name = "${var.project_name}-web-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project_name}-web-profile"
  role = aws_iam_role.web.name
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}