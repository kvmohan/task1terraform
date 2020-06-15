//aws login

provider "aws" {
  region = "ap-south-1"
}

//key-pair

resource "tls_private_key" "taskkey" {
 algorithm = "RSA"
 rsa_bits = 4096
}

resource "aws_key_pair" "key" {
 key_name = "task1key"
 public_key = "${tls_private_key.taskkey.public_key_openssh}"
 depends_on = [
    tls_private_key.taskkey
    ]
}

resource "local_file" "key1" {
 content = "${tls_private_key.taskkey.private_key_pem}"
 filename = "task1key.pem"
  depends_on = [
    aws_key_pair.key
   ]
}

//security-group

resource "aws_security_group" "new" {
  name        = "task1sg"
 
  ingress {
    description = "TCP"
    from_port   = 80	
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

 ingress {
    description = "SSH"
    from_port   = 22	
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

}


 egress {
    from_port   = 0	
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

}  
  tags = {
    Name = "task1sg"
  }
}

//s3-bucket


resource "null_resource" "null2"  {
  provisioner "local-exec" {
      command = "git clone https://github.com/sara16play/task1cloud.git /code"
    }


}

resource "aws_s3_bucket" "new" {
  bucket = "saratask1play"
  acl    = "public-read"
  force_destroy = "true"
}

resource "aws_s3_bucket_object" "image" {
  bucket = "${aws_s3_bucket.new.id}"
  key    = "sara.png"
  source = "/code/sara.png"
  acl = "public-read"
  depends_on = [
    aws_s3_bucket.new
]
}

//cloudfront

resource "aws_cloudfront_distribution" "s3" {
depends_on = [ aws_s3_bucket_object.image]  
origin {
    domain_name = "${aws_s3_bucket.new.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.new.id}"
    
    
}

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "hello"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.new.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "IN"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "null_resource" "nullRemote40" {
   depends_on = [aws_cloudfront_distribution.s3,
                 aws_instance.web,
                 null_resource.nullremote3]
	connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.taskkey.private_key_pem}"
    host     = aws_instance.web.public_ip
    	}


	provisioner "remote-exec" {
		inline = [
			"sudo sed -i 's@path@https://${aws_cloudfront_distribution.s3.domain_name}/${aws_s3_bucket_object.image.key}@g' /var/www/html/index.html"
		]
	}
}

//aws-ec2-launch

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task1key"
  security_groups = [ "task1sg" ]
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.taskkey.private_key_pem}"
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "sara16paly"
  }
  depends_on = [
    local_file.key1,
    aws_s3_bucket_object.image,
    aws_security_group.new,
    aws_cloudfront_distribution.s3
]
    
}


// aws ebs attach

resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1 
  tags = {
    Name = "ebs1"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}


output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}



resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.taskkey.private_key_pem}"
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/sara16play/task1cloud.git /var/www/html/"
    ]
  }
}



resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,
     aws_instance.web
  ]

	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.web.public_ip}"
  	}

}



resource "null_resource" "nulllocal10"  {


depends_on = [
    null_resource.nullremote3,
     aws_instance.web
  ]

provisioner "local-exec"{
 command  =   "rd /s /q /code"
}

}