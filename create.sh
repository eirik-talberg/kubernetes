# Setup k3s-mgmt
ansible-playbook -i k3s/ansible/k3s-mgmt/hosts.ini k3s-ansible/site.yml -K

scp k3s@k3s-mgmt-server-01.g69.io:~/.kube/config ~/.kube/config-k3s-mgmt

# Orchestrate k3s-mgmt
terraform init --chdir=bootstrapping/tf
terraform plan --chdir=bootstrapping/tf
terraform apply --chdir=bootstrapping/tf
