#!/bin/bash

export ANSIBLE_LOCALHOST_WARNING=False

# Load config values (ENV first, then TF, lastly manual config)
if [ -z "$AWX_Hostname" ] && [ -e ../Terraform/terraform.tfstate ]
then
  export AWX_Hostname=$(cat ../Terraform/terraform.tfstate | jq -r .outputs.AWX.value)
elif [ -z "$AWX_Hostname" ]
then
  export AWX_Hostname=$(hostname)
fi
if [ -z "$AWX_Password" ] && [ -e ../Terraform/admin_password ]
then
  export AWX_Password="$(cat ../Terraform/admin_password )"
elif [ -z "$AWX_Password" ]
then
  export AWX_Password=20191125_Micro
fi
if [ -e ../Terraform/vaultfile ]
then
  VAULTFILE=../Terraform/vaultfile
else
  VAULTFILE=vaultfile
fi

# If we've had a secrets.yml file provided in cloud-init, use it.
# If we have a secrets.yml file in ../Terraform (we're running locally). use it.
# Otherwise, just copy run.json to secrets.json :)
if [ -e secrets.yml ]
then
  # Merge run.json and decrypted secrets.yml into a secrets.json file
  ansible-playbook make_secrets_file.yml --vault-password-file="$VAULTFILE"
elif [ -e ../Terraform/secrets.yml ]
then
  cp ../Terraform/secrets.yml .
  # Merge run.json and decrypted secrets.yml into a secrets.json file
  ansible-playbook make_secrets_file.yml --vault-password-file="$VAULTFILE"
  rm secrets.yml
else
  cp run.json secrets.json
fi

# Read config values
export EXTRA_VARS="$(cat secrets.json |
                     sed "s/\$AWX_Hostname/$AWX_Hostname/" |
                     sed "s/\$AWX_Password/$AWX_Password/"
                    )"
# Optionally debug config
if [ -n "$DEBUG" ] ; then echo $EXTRA_VARS | jq . ; fi

# Execute config changes
ansible-playbook configure_awx.yml -e "$EXTRA_VARS"
rm -f secrets.json
