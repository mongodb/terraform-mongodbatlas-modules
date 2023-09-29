
module "aws-fargate" {
  source = "../../modules/aws-fargate"

  database_name = ["test1","test2"]
  region = "US_EAST_1"
  database_user_name = "test1"
  database_password = "test2"

  org_id = "63350255419cf25e3d511c95"
  server_service_ecr_image_uri = "711489243244.dkr.ecr.us-east-1.amazonaws.com/partner-meanstack-atlas-fargate-server:latest"
  web_access_cidr = "10.0.0.0/16"
  availability_zones = ["us-east-1a" , "us-east-1b"]
  environmentId = "dev"
  client_service_ecr_image_uri = "711489243244.dkr.ecr.us-east-1.amazonaws.com/partner-meanstack-atlas-fargate-client:latest"


  mongodb_connection_string = "mongodb+srv://user1:a3OXflXfsGIRjdWk@cluster.0hk0l.mongodb.net/"
}