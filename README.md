# AWX (Ansible Tower) pre-install, configure, and post-install scripts

Welcome! I use these scripts to automate the provisioning of an AWX (Ansible 
Tower) demo environment. It does the following:

1. Install all dependencies of Ansible, AWX and Docker.
2. Prepares the AWX install environment.
3. Installs AWX using the prepared environment.
4. Combines Vault-encrypted secrets with a config file to post-configure AWX.

## Running this script
There is [an example cloud-init.sh](Examples/cloud-init.sh.example) script in
this repo, which can be used in your cloud-init for AWS or Azure. The elements 
of this script are broken down below into their component parts!

### Install Dependencies (Ubuntu)

```bash
apt-get update
apt-get install -y python3-pip python-pip git
pip3 install ansible ansible-tower-cli # I'm preferring Python 3 for Ansible and Tower-CLI
pip2 install docker docker-compose # Ansible at 2.9 uses Python 2 for Docker/Docker-Compose :(
```

### Clone this repo
```bash
git clone https://github.com/JonTheNiceGuy/Install_AWX_And_Configure_It.git /tmp/build_playbook
cd /tmp/build_playbook
```

### Provide your SECRETS to this environment
Note, this should be VAULT encrypted!

See [secrets.yml.example](Examples/secrets.yml.example) for example, plaintext
content.

```bash
echo "<CONTENT>" > secrets.yml
```

### Provide the rest of your post-install config
See [run.json.example](Examples/run.json.example) for example config settings.

```bash
echo "<CONTENT>" > run.json
```

### Put unencrypted details of the install environment into /root
This builds a repeatable script to be able to run the post-install scripts into
the AWX environment.

```bash
mkdir /root/awx_build
echo "#!/bin/bash" > /root/awx_build/creds
echo "export AWX_Hostname=$(hostname)" >> /root/awx_build/creds
echo "export AWX_Password=\"<AWX_ADMIN_PASSWORD>\"" >> /root/awx_build/creds
echo "echo \"<ANSIBLE_VAULT_PASSWORD>\" > /tmp/build_playbook/vaultfile" >> /root/awx_build/creds
echo "echo \"{
  'ansible_fqdn':'$(hostname)',
  'admin_password':'<AWX_ADMIN_PASSWORD>'
}\" > /tmp/build_playbook/extra.json" >> /root/awx_build/creds
echo '$*' >> /root/awx_build/creds
chmod +x /root/awx_build/creds
```

### Run the install scripts
The first script was inspired by https://github.com/geerlingguy/ansible-role-awx
and https://github.com/AgentCormac/ProjectX.

This creates some values (notably the password to use for AWX, and the 
hostname), and clones the AWX repo to a named path. Then it runs the installer
from that repo.
```bash
/root/awx_build/creds ansible-playbook prepare_awx_install.yml -e "@/tmp/build_playbook/extra.json"
cd /opt/awx/installer
ansible-playbook -i inventory install.yml
```

### Post-install
This reads the secrets which were 
[populated above](#Provide-your-SECRETS-to-this-environment) and combines it
with the [post-install config](#Provide-the-rest-of-your-post-install-config)
to create a config file, that is then applied against your AWX server.

```bash
cd /tmp/build_playbook
/root/awx_build/creds bash ./run.sh
```