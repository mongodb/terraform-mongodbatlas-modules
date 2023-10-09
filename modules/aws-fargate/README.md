# quickstart-mongodb-atlas-mean-stack-aws-fargate-integration



## Overview

![simple-quickstart-arch](https://user-images.githubusercontent.com/5663078/229105149-59015114-1c14-44e3-ad5a-b48d9a487797.png)

This Partner Solutions template provides the architecture necessary to scale a [MEAN](https://www.mongodb.com/mean-stack) (MongoDB, Express, Angular, Node.js) stack application using a combination of CloudFormation, MongoDB Atlas, and AWS Fargate. The template leverages the MongoDB Atlas CFN resources to configure the MongoDB infrastructure and AWS CFN resources to set up an Application Load Balancer and a VPC. Additionally, the template employs AWS Fargate to run your Docker image.



## MongoDB Atlas CFN Resources used by the templates

- [mongodbatlas_cluster]
- [mongodbatlas_project_ip_access_list]
- [mongodbatlas_database_user]
- [mongodbatlas_project]
- [mongodbatlas_network_peering]
- [mongodbatlas_Network_container]
- [mongodbatlas_privatelink_endpoint]

## Environment Configured by the Partner Solutions template
The Partner Solutions template will generate the following resources:
- A virtual private cloud (VPC) configured with public and private subnets, according to AWS best practices, to provide you with your own virtual network on AWS. The VPC provides Domain Name System (DNS) resolution. The template leverages the [official AWS quickstart template](https://github.com/aws-quickstart/quickstart-aws-vpc/blob/9dc47510f71f1fb6baf8c4e96b5330a6f51f540e/templates/aws-vpc.template.yaml) to build your VPC infrastructure. See [Deployment Guide](https://aws-quickstart.github.io/quickstart-aws-vpc/) for more information.
- An Atlas Project in the organization that was provided as input.
- An Atlas Cluster with authentication and authorization enabled, and not accessible through the public internet.
- A Database user with access to the Atlas Cluster.
- An Atlas IP access list, allowing the cluster to be accessed through the public internet.
- A VPC peering connection between the MongoDB Atlas VPC (where the cluster is located) and the VPC on AWS.
- An application Load Balancer
- AWS Fargate to run your Docker image. See [fargate-example/](fargate-example/) for an example of docker images to use with Fargate.


