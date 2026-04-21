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
# Initial bootstrap - creates a sudo user named 'ansible'  
useradd -m -s /bin/bash -G sudo ansible
mkdir -p /home/ansible/.ssh
echo "YOUR_PUBLIC_SSH_KEY_HERE" > /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys
echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ansible
```
- Copy droplet's IP address after creation  
  
## Step 2: Setup local Ansible environment  
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
## Step 3: Create Ansible playbook  

```bash
touch playbooks/site.yml
```
Copy and paste file content accordingly (see repository) 

## Step 4: Create supporting files  
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
## Step 5: Run playbook  
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
## Step 6: Confirm configurations  
Log into server (from your local/controller machine):  
```bash
cd ~/.ssh
ssh -i ansible_key ansible@DROPLET_IP_HERE
```
- Test Unattended upgrades:
  ```bash
  sudo systemctl status unattended-upgrades
  cat /etc/apt/apt.conf.d/20auto-upgrades  
  cat /etc/apt/apt.conf.d/50unattended-upgrades | grep -A 5 "Allowed-Origins"
  ```
  <img width="703" height="423" alt="ansible@linux-server_ ~ 4_14_2026 12_46_41 PM" src="https://github.com/user-attachments/assets/287eee18-04e2-4054-a4bf-be4165dfbee3" />  

- Test cron backup script:
  ```bash
  # Run backup script
  sudo /usr/local/bin/backup.sh

  # Check if backup directory exist
  ls -la /mnt/backup_volume/

  # Check backup log
  sudo tail -20 /var/log/backup.log

  # Verify backup contents (should show nginx_configs.tar.gz, exports.backup, containers_list.txt)
  ls -la /mnt/backup_volume/*/
  ```
  <img width="400" height="507" alt="ansible@linux-server_ ~ 4_14_2026 12_55_07 PM" src="https://github.com/user-attachments/assets/02ad78d2-e01e-462b-a88e-1076a508922c" />  
  
- Test Loki: What it does: Collects all server logs and makes them searchable from Grafana
  ```bash
  # check if loki and promtail are running
  docker ps | grep -E "loki|promtail"

  # Check Promtail is collecting logs
  docker logs promtail --tail 20

  # Check Loki is receiving them
  docker logs loki --tail 20
  ```
  <img width="954" height="506" alt="ansible@linux-server_ ~ 4_14_2026 1_08_26 PM" src="https://github.com/user-attachments/assets/f1a7973e-960c-4967-b56b-25f9b9e06847" />  
  
- Test NFS: What it does: Shares a directory from your droplet that other servers can mount
  ```bash
  $ sudo systemctl status nfs-server
  
  # View exported directories
  $ sudo exportfs -v

  # Check if NFS port is open
  $ sudo ufw status | grep 2049
  
  # Create a test mount point & mount the NFS share locally
  sudo mkdir -p /mnt/nfs_test
  sudo mount -t nfs localhost:/srv/nfs_share /mnt/nfs_test

  # Create a test file
  echo "NFS is working" | sudo tee /mnt/nfs_test/test.txt

  # Verify the file appears in the original share
  ls -la /srv/nfs_share/

  # Unmount
  sudo umount /mnt/nfs_test
  ```
- Test NGINX:
  ```bash
  sudo systemctl status nginx
  
  curl -H "Host: YOUR_DOMAIN_NAME_HERE" http:localhost
  ```
  <img width="691" height="300" alt="ansible@linux-server_ ~ 4_14_2026 1_34_28 PM" src="https://github.com/user-attachments/assets/d310c19b-f084-425b-8604-09677c435bf9" />  
  
- Test Backup Script & verify its scheduled execution    
  ```bash
  # Check if cron job exists
  sudo crontab -l | grep backup

  # Check if backup script is executable
  ls -la /usr/local/bin/backup.sh

  # Check backup log for today's automatic backup
  sudo cat /var/log/backup.log
  ```
  <img width="535" height="238" alt="ansible@linux-server_ ~ 4_14_2026 1_38_51 PM" src="https://github.com/user-attachments/assets/5a8c869c-9a0e-4edf-b575-394f9fbd81dc" />
  
- Test fail2ban:
  ```bash
  # multiple failed attempts to log into server will get ur IP banned
  for i in {1..5}; do ssh wronguser@DROPLET_IP_HERE; done
  ```
  Alternative login: Go to Digital Ocean -> Droplet -> Access -> change console user to 'ansible' and log in
  ```bash
  # check list of banned IPs
  sudo fail2ban-client status sshd

  # unban your IP
  sudo fail2ban-client set sshd unbanip YOUR_LOCAL/CONTROLLER_IP_HERE
  ```
  <img width="563" height="563" alt="Droplet Web" src="https://github.com/user-attachments/assets/353d30ad-4b76-4ebb-aaa4-46dc35553cbd" />  
    
## SUMMARY - What's working on your server:  
- Security: SSH key-only, fail2ban blocking attackers, UFW firewall, automatic security patches  
- Web: NGINX serving your domain with virtual hosts  
- Storage: NFS file sharing working  
- Backups: Daily automated backups at 2AM    
- Monitoring: Prometheus collecting node metrics, Grafana dashboard accessible
- Log aggregation and accessibility by Grafana  
- Automation: Entire server deployed with Ansible  
