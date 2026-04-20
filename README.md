## PRE-REQUISITES:  
- Digital Ocean account (or other cloud provider of choice)     
- Local machine with Ubuntu/Debian/Mac (or WSL on Windows)  
- Basic terminal abilities  

## Step 1: Create the Droplet  
- Recommended size is 2vcpu-4gb which is the smallest that can comfortably run this project. You can go bigger for better headroom  
- Distribution: Ubuntu 24.04 LTS  
- Datacenter: Choose option that is geographically closest to you  
- Authentication: SSH key (create one if non-existent)  
- User-data (paste script below for during creation for initial hardening):

```bash
#!/bin/bash
# Initial bootstrap - creates ansible user with sudo
useradd -m -s /bin/bash -G sudo ansible
mkdir -p /home/ansible/.ssh
echo "YOUR_PUBLIC_SSH_KEY_HERE" > /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys
echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ansible
```
- Copy droplet IP address after creation  
  
## Step 2: Setup Local Ansible Environment  
On your local or controller machine, run the following commands:  

```bash
# Create project structure
mkdir ~/linux-server-project
cd ~/linux-server-project
mkdir -p {playbooks,roles,templates,files,inventory}

# Install python & ansible (if not installed already)
sudo apt install python3-pip ansible  

# Create inventory file
cat > inventory/hosts.ini << 'EOF'
[production]
YOUR_DROPLET_IP_HERE ansible_user=ansible

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
```
## Step 3: Create the Ansible playbook  
Copy and paste file contents accordingly (see repository)  

```bash
touch playbooks/site.yml
```  
## Step 4: Create supporting files:  
Copy and paste file contents accordingly (see repository)  

```bash
  # create NGINX virtual host file:  
  touch templates/nginx-vhost.conf.j2

  # create Backup script:  
  touch files/backup_script.sh
 
  # create Docker Compose File:  
  files/docker-compose.yml

  # create Prometheus configuration file:  
  touch files/prometheus.yml
```
  
## Step 5: Run the Playbook  
```bash
cd ~/linux-server-project

# Test connection
ansible -i inventory/hosts.ini production -m ping

# Run in check mode (dry run)
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check

# Run for real
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# If you get errors, run with verbose output
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -vvv
```
