
resource "aws_key_pair" "generated_key" {
  key_name   = "generated_key1"
  public_key = file("../local_key.pub")

tags = {
  Name = "local_key"
}
}

resource "aws_iam_role" "EKS_role" {

  name = "EKS-Role"
  assume_role_policy  = "${file("eks_role.json")}" 

  
}

resource "aws_iam_policy_attachment" "eks_policy" {

  name = "eks_policy_attach"
  roles = [ aws_iam_role.EKS_role.id ]
  policy_arn = data.aws_iam_policy.AmazonEKSClusterPolicy.arn
  
}



resource "aws_iam_role" "nodegroup_role" {

    name = "Nodegroup-Role"
    assume_role_policy = "${file("nodegroup_role.json")}"
  
}

resource "aws_iam_role_policy" "nodegroup_policy" {

    name = "Nodegroup-Policy"
    role = aws_iam_role.nodegroup_role.id
    policy = "${file("nodegroup_policy.json")}"
  
}

resource "aws_iam_policy_attachment" "AmazonEKSWorkerNodePolicy" {

  name = "node_group_attach"
  roles = [ aws_iam_role.nodegroup_role.id ]
  policy_arn = data.aws_iam_policy.AmazonEKSWorkerNodePolicy.arn
  
}

resource "aws_iam_policy_attachment" "AmazonEKS_CNI_Policy" {

  name = "node_group_attach"
  roles = [ aws_iam_role.nodegroup_role.id ]
  policy_arn = data.aws_iam_policy.AmazonEKS_CNI_Policy.arn
  
}

resource "aws_iam_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {

  name = "node_group_attach"
  roles = [ aws_iam_role.nodegroup_role.id ]
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerRegistryReadOnly.arn
  
}




resource "aws_vpc" "eks_vpc" {

    cidr_block = var.cidr_value
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
      "Name" = "${var.project}_VPC"
      "Project" = "${var.project}"
      "kubernetes.io/cluster/my-eks-cluster" = "shared"
    }
  
}

resource "aws_subnet" "public_subnet" {
  
  count = 3
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = cidrsubnet(var.cidr_value, 3, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    "Name" = "${var.project}_public_${count.index+1}"
    "Project" = "${var.project}"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = 1

  }
}

resource "aws_subnet" "private_subnet" {

  count = 3
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = cidrsubnet(var.cidr_value,3,count.index+3)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    "Name" = "${var.project}_private_${count.index+1}"
    "Project" = "${var.project}"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
  
}

resource "aws_internet_gateway" "IG" {

  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    "Name" = "${var.project}_IG"
    "Project" = "${var.project}"
  }
  
}


resource "aws_route_table" "public_route_table" {

  vpc_id = aws_vpc.eks_vpc.id
  
  route  {
    
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG.id

  }

  route {
    ipv6_cidr_block  = "::/0"
    gateway_id = aws_internet_gateway.IG.id

  }

  tags = {
    "Name" = "${var.project}_public-route"
    "Project" = "${var.project}"
  }
  
}


resource "aws_eip" "elastic" {
  vpc      = true
}

resource "aws_nat_gateway" "natgateway" {
  
  allocation_id = aws_eip.elastic.id
  subnet_id = aws_subnet.public_subnet[0].id

  tags = {
    "Name" = "${var.project}_NGW"
    "Project" = "${var.project}"
  }

}

resource "aws_route_table" "private_route_table" {

  vpc_id = aws_vpc.eks_vpc.id

   route  {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgateway.id
  }

  tags = {
    "Name" = "${var.project}_private-route"
    "Project" = "${var.project}"
  }
  
}

resource "aws_route_table_association" "public_association" {
  count = 3
  subnet_id = aws_subnet.public_subnet[count.index].id 
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_association" {

  count = 3
  subnet_id = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
  
}


resource "aws_security_group" "ssh_sg" {

  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id = aws_vpc.eks_vpc.id

  ingress {
    description      = "SSH to VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
  
}

resource "aws_eks_cluster" "my-eks-cluster" {

    name = "my-eks-cluster"
    role_arn = aws_iam_role.EKS_role.arn
    version = "${var.eks_version}"

    vpc_config {

        subnet_ids = [ aws_subnet.public_subnet[0].id , aws_subnet.public_subnet[1].id, aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id]
        security_group_ids = [aws_security_group.ssh_sg.id]
        endpoint_private_access = true
        endpoint_public_access = true

    }

    tags = {
     
      "Name" = "${var.project}_eks_cluster"

    }
  
}

resource "aws_eks_node_group" "eks_nodegroup" {

    cluster_name = aws_eks_cluster.my-eks-cluster.id
    node_group_name = "eks_nodegroup"
    node_role_arn = aws_iam_role.nodegroup_role.arn
    instance_types = ["${var.instance-type}"]
    disk_size = "8"
    subnet_ids = [ aws_subnet.public_subnet[0].id , aws_subnet.public_subnet[1].id, aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id]

    scaling_config {
      desired_size = 1
      max_size = 1
      min_size = 1

    }

    remote_access {
      ec2_ssh_key = aws_key_pair.generated_key.id
    }
}



