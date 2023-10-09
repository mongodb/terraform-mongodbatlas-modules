data "aws_partition" "current" {}
data "aws_region" "current" {name = "us-east-1"}


data aws_caller_identity "current" {}

# Define AWS provider configuration
provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# Create DHCP Options
resource "aws_vpc_dhcp_options" "meanstack_dhcp_options" {
  domain_name = "ec2.internal"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Name = "meanstack- stack DHCPOptions"
  }
}

# Create VPC
resource "aws_vpc" "meanstack_vpc" {
  cidr_block = var.vpccidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "aws-meanstack-fargate-vpc"
  }
}

# Associate VPC with DHCP Options
resource "aws_vpc_dhcp_options_association" "meanstack_dhcp_association" {
  vpc_id = aws_vpc.meanstack_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.meanstack_dhcp_options.id
}

# Create Internet Gateway
resource "aws_internet_gateway" "meanstack_igw" {
  vpc_id = aws_vpc.meanstack_vpc.id
}

# Create Public Subnets
resource "aws_subnet" "public_subnets" {
  count = 2
  vpc_id = aws_vpc.meanstack_vpc.id
  cidr_block = element([var.public_subnet1_cidr,var.public_subnet2_cidr], count.index)
  availability_zone = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private_subnets" {
  count = 2
  vpc_id = aws_vpc.meanstack_vpc.id
  cidr_block = element([var.private_subnet1_cidr,var.private_subnet2_cidr], count.index)
  availability_zone = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# Create NAT Gateways
resource "aws_nat_gateway" "meanstack_nat_gateways" {
  count = 2
  allocation_id = aws_eip.nat_ips[count.index].id
  subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat_ips" {
  count = 2
}

# Create Route Table for Private Subnets
resource "aws_route_table" "private_routes" {
  count = 2
  vpc_id = aws_vpc.meanstack_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.meanstack_nat_gateways[*].id, count.index)
  }
}

# Associate Private Subnets with Route Tables
resource "aws_route_table_association" "private_subnet_association" {
  count = 2
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = element(aws_route_table.private_routes[*].id, count.index)
}


resource "aws_ecs_cluster" "my_cluster" {
  name = "partner-meanstack-atlas-fargate-3"
  tags = {
    environment_name = var.environmentId
    Project = "MongoDbTerraformProvider"
    created_by = "aws-farget"
    creation_date = timestamp()
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_security_group" "meanstack_sg" {
  name = "meanstack-sg-3"
  description = "Meanstack security group"
  vpc_id = aws_vpc.meanstack_vpc.id
  
  # Inbound rule for port 8080
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere
  }

  # Inbound rule for port 5200
  ingress {
    from_port   = 5200
    to_port     = 5200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere
  }


}

resource "aws_ecs_service" "server_service" {
  depends_on = [aws_lb_listener.server_listener]
  name = "server_service"
  cluster = aws_ecs_cluster.my_cluster.arn
  task_definition = aws_ecs_task_definition.server_task_definition.arn
  desired_count = 1
  launch_type = "FARGATE"
  platform_version = "1.4.0"
  propagate_tags = "SERVICE"
  scheduling_strategy = "REPLICA"
  
  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets = [ aws_subnet.public_subnets[0].id , aws_subnet.public_subnets[1].id]  # Replace with your subnet IDs
    security_groups = [aws_security_group.meanstack_sg.id]         # Replace with your security group ID
    assign_public_ip = true
  }
  service_registries {
    registry_arn = aws_service_discovery_service.server_service_discovery_entry.arn
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.ServerTCP5200TargetGroup.arn
    container_name   = "server"
    container_port   = 5200
  }
  tags = {
    environment_name = var.environmentId
    Project = "MongoDbTerraformProvider"
    created_by = "aws-farget"
    creation_date = timestamp()
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_ecs_service" "client_service" {
  name            = "client-service"
  cluster         = aws_ecs_cluster.my_cluster.arn
  task_definition = aws_ecs_task_definition.client_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets = [
      aws_subnet.public_subnets[0].id,
      aws_subnet.public_subnets[1].id,
    ]

    security_groups = [
      aws_security_group.meanstack_sg.id
    ]

    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ClientTCP8080TargetGroup.arn
    container_name   = "client"
    container_port   = 8080
  }

  platform_version = "1.4.0"
  propagate_tags   = "SERVICE"
  scheduling_strategy = "REPLICA"

  service_registries {
    registry_arn = aws_service_discovery_service.client_service_discovery_entry.arn
  }

  tags = {
    environment_name = var.environmentId
    Project = "MongoDbTerraformProvider"
    created_by = "aws-farget"
    creation_date = timestamp()
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_ecs_task_definition" "client_task_definition" {

    container_definitions = jsonencode([
        {
          name        = "Client_ResolvConf_InitContainer"
          image       = "docker/ecs-searchdomain-sidecar:1.0"
          essential   = false
          command     = ["us-east-1.compute.internal", "partner-meanstack-atlas-fargate.local"]
          environment = [
            {
              name  = "ATLAS_URI"
              value = "http://${aws_lb.mean-stack-lb.dns_name}:5200"
            }
          ]
          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"        = aws_cloudwatch_log_group.LogGroup.name
              "awslogs-region"       = data.aws_region.current.name
              "awslogs-stream-prefix" = "partner-meanstack-atlas-fargate"
            }
          }
        },
        {
          depends_on = [
            {
              "containerName"= "Client_ResolvConf_InitContainer",
              "condition"= "SUCCESS"
            }
          ]
          name            = "client"
          image           = var.client_service_ecr_image_uri
          essential: true
          environment = [
            {
              name  = "ATLAS_URI"
              value = "http://${aws_lb.mean-stack-lb.dns_name}:5200"
            }
          ]
          depends_on = [
          {
              "containerName"= "Client_ResolvConf_InitContainer",
              "condition"= "SUCCESS"
          }
        ]
          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"        = aws_cloudwatch_log_group.LogGroup.name
              "awslogs-region"       = data.aws_region.current.name
              "awslogs-stream-prefix" = "partner-meanstack-atlas-fargate"
            }
          }
          portMappings = [
            {
              containerPort = 8080
              hostPort      = 8080
              protocol       = "tcp"
            }
          ]
        },
    ])
    cpu = "256"
    execution_role_arn = aws_iam_role.server_task_execution_role.arn
    task_role_arn            = aws_iam_role.AtlasIAMRole.arn
    family = "partner-meanstack-atlas-fargate-client"
    memory = "512"
    network_mode = "awsvpc"
    requires_compatibilities = [
      "FARGATE"
    ]
  
}

resource "aws_ecs_task_definition" "server_task_definition" {
    
  
    container_definitions = jsonencode([
      {
        name        = "Server_ResolvConf_InitContainer"
        image       = "docker/ecs-searchdomain-sidecar:1.0"
        essential   = false
        command     = ["us-east-1.compute.internal", "partner-meanstack-atlas-fargate.local"]
        environment = [
            {
              name  = "ATLAS_URI"
              value = "http://${aws_lb.mean-stack-lb.dns_name}:5200"
            }
          ]
          log_configuration = {
            log_driver = "awslogs"
            options = {
              "awslogs-group"        = aws_cloudwatch_log_group.LogGroup.name
              "awslogs-region"       = data.aws_region.current.name
              "awslogs-stream-prefix" = "partner-meanstack-atlas-fargate"
            }
          }
    },
      {
        name            = "server"
        image           = var.server_service_ecr_image_uri
        essential       = true
        environment = [
          {
            name  = "ATLAS_URI"
            value = var.mongodb_connection_string
          }
        ]
        depends_on      = [
          {
            "containerName" = "Server_ResolvConf_InitContainer",
            "condition"      = "SUCCESS"
          }
        ]
        
        log_configuration = {
          log_driver = "awslogs"
          options = {
            "awslogs-group"        = aws_cloudwatch_log_group.LogGroup.name
            "awslogs-region"       = data.aws_region.current.name
            "awslogs-stream-prefix" = "partner-meanstack-atlas-fargate"
          }
        }
        portMappings = [
          {
            containerPort = 5200
            hostPort      = 5200
            protocol       = "tcp"
          }
        ]
      },
    ])
    cpu                      = "256"
    execution_role_arn = aws_iam_role.server_task_execution_role.arn
    task_role_arn            = aws_iam_role.AtlasIAMRole.arn
    family                   = "partner-meanstack-atlas-fargate-server"
    memory                   = "512"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]

}

resource "aws_iam_role" "execution_role" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
  tags = {
    environment_name = var.environmentId
    Project = "MongoDbTerraformProvider"
    created_by = "aws-farget"
    creation_date = timestamp()
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_iam_role" "client_task_execution_role" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Sid = ""
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
  tags = {
    environment_name = var.environmentId
    Project = "MongoDbTerraformProvider"
    created_by = "aws-farget"
    creation_date = timestamp()
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_iam_role" "server_task_execution_role" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Sid = ""
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
  tags = {
    environment_name = var.environmentId
    Project = "MongoDbTerraformProvider"
    created_by = "aws-farget"
    creation_date = timestamp()
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_lb_target_group" "ClientTCP8080TargetGroup" {
  port = 8080
  target_type = "ip"
  protocol = "TCP"
  vpc_id = aws_vpc.meanstack_vpc.id
}

resource "aws_lb_target_group" "ServerTCP5200TargetGroup" {
  port = 5200
  target_type = "ip"
  protocol = "TCP"
  vpc_id = aws_vpc.meanstack_vpc.id
}

resource "aws_lb" "mean-stack-lb" {
  name               = "mean-stack-lb-3"
  internal           = false  # Set to true for an internal NLB
  load_balancer_type = "network"
  enable_deletion_protection = false  # Setto true to enable deletion protection

  subnets = [aws_subnet.public_subnets[0].id,aws_subnet.public_subnets[0].id,]  # Specify your subnet IDs
}

resource "aws_lb_listener" "client_listener" {
  load_balancer_arn = aws_lb.mean-stack-lb.arn
  port              = 8080
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ClientTCP8080TargetGroup.arn
  }
}

resource "aws_lb_listener" "server_listener" {
  load_balancer_arn = aws_lb.mean-stack-lb.arn
  port              = 5200
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ServerTCP5200TargetGroup.arn
  }
}

resource "aws_lb_target_group" "client_target_group" {
    name        = "client-target-group-3"
    port        = 8080
    protocol    = "TLS"
    target_type = "ip"
    vpc_id      = aws_vpc.meanstack_vpc.id # Replace with your VPC ID
}

resource "aws_lb_target_group" "server_target_group" {
    name        = "server-target-group-3"
    port        = 5200
    protocol    = "TLS"
    target_type = "ip"
    vpc_id      = aws_vpc.meanstack_vpc.id # Replace with your VPC ID
}


resource "aws_service_discovery_service" "client_service_discovery_entry" {
  description = "Client service discovery entry in Cloud Map"
  name = "client_service_discovery_entry"
  dns_config {
    namespace_id    = aws_service_discovery_private_dns_namespace.cloud_map.id
    routing_policy  = "MULTIVALUE"  # Specify your routing policy
    dns_records {
      ttl  = 60
      type = "A"
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_private_dns_namespace" "cloud_map" {
  description = "Service Map for Docker Compose project partner-meanstack-atlas-fargate"
  name = "partner-meanstackatlas-fargate.local"
  vpc = aws_vpc.meanstack_vpc.id
}


resource "aws_service_discovery_service" "server_service_discovery_entry" {
  description = "Server service discovery entry in Cloud Map"
  name = "server_service_discovery_entry"
  namespace_id    = aws_service_discovery_private_dns_namespace.cloud_map.id
  dns_config {
    namespace_id    = aws_service_discovery_private_dns_namespace.cloud_map.id
    routing_policy  = "MULTIVALUE"  # Specify your routing policy
    dns_records {
      ttl  = 60
      type = "A"
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_iam_role" "AtlasIAMRole" {
  name = "AtlasIAMRole-3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com",
          AWS     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = "sts:AssumeRole",
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        },
        Action = "sts:AssumeRole",
      },
    ],
  })

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}

resource "aws_cloudwatch_log_group" "LogGroup" {
  name = "/docker-compose/partner-meanstack-atlas-fargate-3"
}