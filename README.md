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
## Step 3: Create the Ansible playbook  

```bash
touch playbooks/site.yml
```
Copy and paste file content accordingly (see repository) 

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
Log into server(from your local/controller machine):  
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
- Test Loki (Log Aggregation): What it does: Collects all server logs and makes them searchable from Grafana
  ```bash
  # check if loki and promtail are running
  docker ps | grep -E "loki|promtail"

  # Check Promtail is collecting logs
  docker logs promtail --tail 20

  # Check Loki is receiving them
  docker logs loki --tail 20
  ```
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
  
- Test Backup Script & verify its scheduled execution    
  ```bash
  # Check if cron job exists
  sudo crontab -l | grep backup

  # Check if backup script is executable
  ls -la /usr/local/bin/backup.sh

  # Check backup log for today's automatic backup
  sudo cat /var/log/backup.log
  ```
## SUMMARY: What's Working on Your Server:  
- Security: SSH key-only, fail2ban blocking attackers, UFW firewall, auto security patches  
- Web: NGINX serving your domain with virtual hosts  
- Storage: NFS file sharing working  
- Backups: Daily automated backups at 2AM    
- Monitoring: Prometheus collecting node metrics, Grafana dashboard accessible  
- Automation: Entire server deployed with Ansible  
