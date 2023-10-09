
module "aws-fargate" {
  source = "../../modules/aws-fargate"

  database_name = ["test1","test2"]
  region = "US_EAST_1"
  database_user_name = "test1"
  database_password = ""

  org_id = ""
  server_service_ecr_image_uri = "711489243244.dkr.ecr.us-east-1.amazonaws.com/partner-meanstack-atlas-fargate-server"
  availability_zones = ["us-east-1a" , "us-east-1b"]
  environmentId = "dev"
  client_service_ecr_image_uri = "711489243244.dkr.ecr.us-east-1.amazonaws.com/partner-meanstack-atlas-fargate-client:latest"
  atlas_org_id = ""
  public_key = "ghewvngy"
  password = ["", ""]
  private_key = ""
  mongodb_connection_string = "mongodb+srv://<connstring>"

  securitygroupid = "sg-00ef8d7071c1a3b09"
  subnetid1 = "subnet-0cdc42b2b52c812bf"
  subnetid2 = "subnet-0b4b72f62625b06c2"
  vpcid = "vpc-05535f04b8eab37bf"

}