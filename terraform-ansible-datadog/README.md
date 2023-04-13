# Prérequies
- Installer aws cli
- Installer ansible
- installer terraform

# Gestion des accès
créer un utilisateur IAM
generer les accès key et secret key de l'utilisateur IAM
Télécharger les accès key et secret key
configurer votre aws cli accès avec la commande aws configure
copier ensuite les accès key télécharger et les mettre sur la configuration

# Installation de datadog ansible galaxy 
Installer datadog.datadog pour pouvoir éxecuter le playbook ansible
sudo ansible-galaxy install datadog.datadog
Copier le fichier datadog.datadog spécifier dans le répertoire après installation dans le répertoire d'ansible par défaut
sudo cp -R /home/user/.ansible/roles/datadog.datadog /etc/ansible/roles

# Création de cle ssh pour se connecter sur la ressource aws
la commande de création de cle ssh se trouve sur le fichier ssh.md
Assurer vous que vous ne disposer pas le même nom de cle sur votre compte aws dans la même région

# Tester la configuration
Placer vous dans le repertoire du projet /terraform-ansible-datadog
- Initialiser terraform
  terraform init
- Vérifier la configuration
  terraform plan -var-file="user.auto.tfvars"
- Concevoir les ressources
  terraform apply -var-file="user.auto.tfvars" 

Tout serq automatique. Cela fournira toutes les ressources aws nécessaires et également créera et démarrera un serveur Web à l'aide d'Ansible.

# Supprimer les ressources dans aws
terraform destroy -var-file="user.auto.tfvars" 
