
module "aws-fargate" {
  source = "../../modules/aws-fargate"

  atlas_org_id = ""
  public_key = ""
  private_key = ""


  region = "US_EAST_1"
  server_service_ecr_image_uri = ""
  availability_zones = ["us-east-1a" , "us-east-1b"]
  environmentId = "development"
  client_service_ecr_image_uri = ""
  mongodb_connection_string = ""

  vpc-id = ""
  subnet-id1 = ""
  subnet-id2 = ""
  securitygroup-id = ""
}