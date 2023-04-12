provider "aws" {
  region                  = var.region
  shared_credentials_files =[var.shared_credentials_file]
  profile                  = "default"
}


# Création de VPC
resource "aws_vpc" "datadog-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true" #vous donne un nom de domaine interne
  enable_dns_hostnames = "true" #vous donne un nom d'hôte interne
  
  instance_tenancy     = "default"

}

# Création de sous-réseau public pour EC2
resource "aws_subnet" "datadog-subnet-public-ec2" {
  vpc_id                  = aws_vpc.datadog-vpc.id // l'id du vpc créer à la ligne 9
  cidr_block              = "10.0.1.0/24" // Adresse réseau avec notation CIDR
  map_public_ip_on_launch = "true" //cela en fait un sous-réseau public
  availability_zone       = var.AZ1 // Choix du zone de disponibilité

}


# Création de pare feu (IGW) pour la connexion internet 
resource "aws_internet_gateway" "datadog-igw" {
  vpc_id = aws_vpc.datadog-vpc.id

}

# Création de table de routage (Route table) 
resource "aws_route_table" "datadog-public-route-table" {
  vpc_id = aws_vpc.datadog-vpc.id

  route {
    //le sous-réseau associé peut atteindre n'importe où
    cidr_block = "0.0.0.0/0"
    //le table de routage utilise le pare feu IGW pour accéder à Internet
    gateway_id = aws_internet_gateway.datadog-igw.id
  }


}


# Associer la table de routage au sous-réseau public
resource "aws_route_table_association" "datadog-rta-public-subnet-1" {
  // rta = route table association
  subnet_id      = aws_subnet.datadog-subnet-public-ec2.id
  route_table_id = aws_route_table.datadog-public-route-table.id
}



//Groupe de sécurité pour l'instance EC2

resource "aws_security_group" "datadog-ec2_allow_rule" {

  // Activer que ses ports entrants
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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

  // Autoriser tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  // Lier le groupe de sécurité au VPC créer prélablement
  vpc_id = aws_vpc.datadog-vpc.id
  tags = {
    Name = "allow ssh,http,https"
  }
}


# modifier la valeur de la variable USERDATA par le playbook
data "template_file" "playbook" {
  template = file("${path.module}/datadog-playbook.yml")
  vars = {
    datadog_user      = "${var.datadog_user}"
    datadog_password  = "${var.datadog_password}"
    datadog_api_key   = "${var.DATADOG_API_KEY}"
  }
}


# Création de EC2
resource "aws_instance" "datadog-agent" {
  ami             = var.ami
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.datadog-subnet-public-ec2.id
  vpc_security_group_ids = ["${aws_security_group.datadog-ec2_allow_rule.id}"]
  
  key_name = aws_key_pair.mykey-pair.id
  tags = {
    Name = "Datadog-agent"
  }

}

// Envoie votre clé publique à l'instance
resource "aws_key_pair" "mykey-pair" {
  key_name   = "mykey-pair" // nom du clé sur l'instance
  public_key = file(var.PUBLIC_KEY_PATH) // chemin d'accès du clé à copier
}

# création d'Elastic IP pour fixer l'adresse IP de l'EC2
resource "aws_eip" "eip" {
  instance = aws_instance.datadog-agent.id

}

# affichage de l'adresse IP de l'ec2
output "IP" {
  value = aws_eip.eip.public_ip
}

// Commande de sortie après avoir finie le provisionning
output "INFO" {
  value = "Les ressources AWS ont été provisionnées. Go to http://${aws_eip.eip.public_ip}"
}

# Enregistrer le contenu du playbook rendu dans un fichier local
resource "local_file" "playbook-rendered-file" {
  content = "${data.template_file.playbook.rendered}"
  filename = "./playbook-rendered.yml"
}

resource "null_resource" "datadog_agent_Installation_Waiting" {

  triggers={
    ec2_id=aws_instance.datadog-agent.id
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.PRIV_KEY_PATH)
    host        = aws_eip.eip.public_ip
    timeout     = "4m"
  }


 # Exécuter le script pour mettre à jour le client distant
  provisioner "remote-exec" {
     
     inline = ["sudo yum update -y", "echo Done!"]
   
  }

# Executer le playbook ansible 
  provisioner "local-exec" {
     command = <<EOT
     ansible-galaxy install datadog.datadog;
     export ANSIBLE_HOST_KEY_CHECKING=False; 
     ansible-playbook -u ec2-user -i '${aws_eip.eip.public_ip},' --private-key ${var.PRIV_KEY_PATH}  playbook-rendered.yml
     
     EOT  
  }

}


