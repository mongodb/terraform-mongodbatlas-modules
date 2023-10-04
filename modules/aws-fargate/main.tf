data "aws_partition" "current" {}
data "aws_region" "current" {}

data aws_caller_identity "current" {}

resource "aws_ecs_cluster" "my_cluster" {
  name = "partner-meanstack-atlas-fargate-1"
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
  name = "client_service-1"
  cluster = aws_ecs_cluster.my_cluster.id
  desired_count = 1
  launch_type = "FARGATE"
  platform_version = "1.4.0"
  propagate_tags = "SERVICE"
  scheduling_strategy = "REPLICA"
  network_configuration {
    assign_public_ip = true
    subnets = [aws_subnet.subnet_east_a.id, aws_subnet.subnet_east_b.id]  # Replace with your subnet IDs
    security_groups = [aws_security_group.default_network.id]           # Replace with your security group ID
  }
  task_definition = aws_ecs_task_definition.client_task_definition.arn
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
          name            = "client"
          image           = var.client_service_ecr_image_uri
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
          port_mappings = [
            {
              container_port = 8080
              host_port      = 8080
              protocol       = "tcp"
            }
          ]
        },
    ])
    cpu = "256"
    execution_role_arn = aws_iam_role.execution_role.arn
    family = "partner-meanstack-atlas-fargate-client"
    memory = "512"
    network_mode = "awsvpc"
    requires_compatibilities = [
      "FARGATE"
    ]
  
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

resource "aws_lb_target_group" "ClientTCP8080TargetGroup" {
  name = "ClientTCP8080TargetGroup"
  port = 8080
  target_type = "ip"
  protocol = "TCP"
  vpc_id = aws_vpc.vpc_east.id
}

resource "aws_lb_target_group" "ServerTCP5200TargetGroup" {
  name = "ServerTCP5200TargetGroup"
  port = 5200
  target_type = "ip"
  protocol = "TCP"
  vpc_id = aws_vpc.vpc_east.id
}

resource "aws_lb" "mean-stack-lb" {
  name               = "mean-stack-lb-1"
  internal           = false  # Set to true for an internal NLB
  load_balancer_type = "network"

  enable_deletion_protection = false  # Set to true to enable deletion protection

  subnets = [aws_subnet.subnet_east_a.id, aws_subnet.subnet_east_b.id]  # Specify your subnet IDs
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


resource "aws_internet_gateway" "mean-stack-internet-gateway" {
  vpc_id = aws_vpc.vpc_east.id  # Replace with your VPC ID
}


resource "aws_lb_target_group" "client_target_group" {
    name        = "my-ecs-target-group"
    port        = 8080
    protocol    = "TLS"
    target_type = "ip"
    vpc_id      = aws_vpc.vpc_east.id # Replace with your VPC ID
  }

resource "aws_service_discovery_service" "client_service_discovery_entry" {
  description = "Client service discovery entry in Cloud Map"
  name = "client_service_discovery_entry"
  dns_config {
    namespace_id    = aws_service_discovery_private_dns_namespace.cloud_map.id
    routing_policy  = "MULTIVALUE"  # Specify your routing policy
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_security_group" "default_network" {
  description = "partner-meanstack-atlas-fargate Security Group for default network"
  vpc_id = aws_vpc.vpc_east.id
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

resource "aws_security_group" "client_default_network" {
  description = "partner-meanstack-atlas-fargate Security Group for client default network"
  vpc_id = aws_vpc.vpc_east.id
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

resource "aws_security_group" "server_default_network" {
  description = "partner-meanstack-atlas-fargate Security Group for server default network"
  vpc_id = aws_vpc.vpc_east.id
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

resource "aws_vpc" "vpc_east" {
  cidr_block           = "11.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "subnet_east_a" {
  vpc_id                  = aws_vpc.vpc_east.id
  cidr_block              = "11.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zones[0]
}

resource "aws_subnet" "subnet_east_b" {
  vpc_id                  = aws_vpc.vpc_east.id
  cidr_block              = "11.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = var.availability_zones[1]
}

resource "aws_service_discovery_private_dns_namespace" "cloud_map" {
  description = "Service Map for Docker Compose project partner-meanstack-atlas-fargate"
  name = "partner-meanstack-atlas-fargate.local"
  vpc = aws_vpc.vpc_east.id
}

resource "aws_security_group_rule" "Default5200Ingress" {
  type        = "ingress"
  from_port   = 5200          # Specify the source port or port range
  to_port     = 5200          # Specify the destination port or port range
  protocol    = "tcp"       # Specify the protocol ("tcp", "udp", "icmp", etc.)
  cidr_blocks = ["0.0.0.0/0"]  # Specify the allowed source IP range (0.0.0.0/0 allows all)

  security_group_id = aws_security_group.default_network.id  # Reference your security group ID
}

resource "aws_security_group_rule" "Default8080Ingress" {
  type        = "ingress"
  from_port   = 8080          # Specify the source port or port range
  to_port     = 8080          # Specify the destination port or port range
  protocol    = "tcp"       # Specify the protocol ("tcp", "udp", "icmp", etc.)
  cidr_blocks = ["0.0.0.0/0"]  # Specify the allowed source IP range (0.0.0.0/0 allows all)

  security_group_id = aws_security_group.client_default_network.id  # Reference your security group ID
}

resource "aws_security_group_rule" "DefaultNetwork" {
  type        = "ingress"
  protocol = "-1"
  security_group_id  = aws_security_group.default_network.id
  source_security_group_id = aws_security_group.default_network.id
  description        = "Allow communication within network default."
  from_port = 0
  to_port = 0
}

resource "aws_ecs_service" "server_service" {
  depends_on = [aws_lb_listener.server_listener]
  name = "server_service"
  cluster = aws_ecs_cluster.my_cluster.id
  desired_count = 1
  launch_type = "FARGATE"
  platform_version = "1.4.0"
  propagate_tags = "SERVICE"
  scheduling_strategy = "REPLICA"

  network_configuration {
    subnets = [aws_subnet.subnet_east_a.id, aws_subnet.subnet_east_b.id]  # Replace with your subnet IDs
    security_groups = [aws_security_group.default_network.id]         # Replace with your security group ID
  }
  task_definition = aws_ecs_task_definition.server_task_definition.arn
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

resource "aws_service_discovery_service" "server_service_discovery_entry" {
  description = "Server service discovery entry in Cloud Map"
  namespace_id    = aws_service_discovery_private_dns_namespace.cloud_map.id
  name = "server"
  dns_config {
    namespace_id    = aws_service_discovery_private_dns_namespace.cloud_map.id
    routing_policy  = "MULTIVALUE"  # Specify your routing policy
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}


resource "aws_ecs_task_definition" "server_task_definition" {
  family                   = "partner-meanstack-atlas-fargate-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn = aws_iam_role.client_task_execution_role.arn
  task_role_arn            = aws_iam_role.AtlasIAMRole.arn

  container_definitions = jsonencode([
    {
      name        = "Server_ResolvConf_InitContainer"
      image       = "docker/ecs-searchdomain-sidecar:1.0"
      essential   = false
      command     = ["us-east-1.compute.internal", "partner-meanstack-atlas-fargate.local"]
    },
    {
      name            = "server"
      image           = var.server_service_ecr_image_uri
      essential       = true
      depends_on      = [
        {
          container_name = "Server_ResolvConf_InitContainer"
          condition      = "SUCCESS"
        }
      ]
      environment = [
        {
          name  = "ATLAS_URI"
          value = var.mongodb_connection_string
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
      port_mappings = [
        {
          container_port = 5200
          host_port      = 5200
          protocol       = "tcp"
        }
      ]
    },
  ])
}

resource "aws_iam_role" "AtlasIAMRole" {
  name = "AtlasIAMRole"

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
  name = "/docker-compose/partner-meanstack-atlas-fargate"
}