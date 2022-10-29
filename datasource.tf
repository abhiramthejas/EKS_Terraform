data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "available_ami" {

  most_recent      = true
  owners           = ["amazon"]


 filter {
   name = "name"
   values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
 }

 filter {
   
   name = "virtualization-type"
   values = ["hvm"]
 }

}


data "aws_iam_policy" "AmazonEKSClusterPolicy" {
  name = "AmazonEKSClusterPolicy"
}

data "aws_iam_policy" "AmazonEKSWorkerNodePolicy"{

  name = "AmazonEKSWorkerNodePolicy"
}

data "aws_iam_policy" "AmazonEC2ContainerRegistryReadOnly" {

  name = "AmazonEC2ContainerRegistryReadOnly"
  
}

data "aws_iam_policy" "AmazonEKS_CNI_Policy" {

  name = "AmazonEKS_CNI_Policy"
  
}

