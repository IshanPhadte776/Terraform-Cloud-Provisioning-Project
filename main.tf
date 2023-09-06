# Define the required providers block, specifying that this configuration uses the AWS provider.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"    # The source of the AWS provider, specifying HashiCorp's official provider.
      version = "~> 4.16"           # Specify the desired version or version range of the AWS provider.
    }
  }

  required_version = ">= 1.2.0"     # Specify the minimum Terraform version required to apply this configuration.
}

# Define the AWS provider block, specifying the region where resources will be provisioned.
provider "aws" {
  region  = "us-west-2"             # Set the AWS region to us-west-2 (US West - Oregon).
}

#identifier is vpc1
resource "aws_vpc" "vpc1" {
  #Defines the IP range for the VPC
  cidr_block = "172.16.0.0/16"
  #tags for labeling and organizational purposes
  tags = {
    Name = "vpc-example"
  }
}

resource "aws_subnet" "my_subnet" {
  #subnet in the vpc
  vpc_id            = aws_vpc.vpc1.id
  #subnet has less ip addresses compared to the vpc
  cidr_block        = "172.16.10.0/24"
  #use 1 az
  availability_zone = "us-west-2b"

  tags = {
    Name = "vpc-example"
  }
}
#Allows the ec2 in the vpc to communicate with the network and internet
resource "aws_network_interface" "network-interface" {
  subnet_id   = aws_subnet.my_subnet.id
  private_ips = ["172.16.10.100"]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_iam_policy" "ec2policies" {
  name        = "access-policy"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstanceStatus",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:StartInstances",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:StopInstances",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:RebootInstances",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:TerminateInstances",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:AuthorizeSecurityGroupIngress",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:CreateTags",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:CreateKeyPair",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DeleteKeyPair",
      "Resource": "*"
    }
  ]
}
EOF
}

#provides permissons to other AWS services
resource "aws_iam_instance_profile" "instance_profile" {
  name = "instance-profile"
  role = aws_iam_role.iam_role.name
}

resource "aws_iam_role" "iam_role" {
  name = "example-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "policy_attachment" {
  name       = "policy-attachment"
  policy_arn = aws_iam_policy.ec2policies.arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_instance" "ec2instance" {
  ami           = "ami-005e54dee72cc1d00" # us-west-2
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name


  network_interface {
    network_interface_id = aws_network_interface.network-interface.id
    device_index         = 0
  }

  credit_specification {
    cpu_credits = "unlimited"
  }
}

resource "aws_security_group" "security-group" {
  name        = "example-security-group"
  vpc_id = aws_vpc.vpc1.id

  # Ingress rule for SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust this CIDR block to limit SSH access to trusted IP ranges
  }

  # Ingress rule for HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust this CIDR block to limit HTTP access to trusted IP ranges
  }
  # You can add more ingress rules as needed

  # Egress rules are not explicitly defined here; AWS allows all outbound traffic by default

  tags = {
    Name = "security-group"
  }
}

resource "aws_volume_attachment" "ebs_volume" {
  device_name = "/dev/sdh"
  volume_id = aws_ebs_volume.ebsvolume.id
  instance_id = aws_instance.ec2instance.id

}

resource "aws_ebs_volume" "ebsvolume" {
  availability_zone = "us-west-2b"
  size = 1
}