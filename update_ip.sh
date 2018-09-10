#!/bin/bash

###Change the below to suit your environment

#password to mikrotik user
export SSHPASS="pass"

#Username to mikrotik router
mikrotik_user=ssh_user

#Address of router
mikrotik_addr=192.168.0.1

#PPPOE device name
mikrotik_dev_name=sometelco

#Port number to update
port_num=22

#Description of fw rule purpose
rule_desc=SSH_access_from_HOME

#AWS CLI credentials file (by default you dont need to change if it`s under the running users's home)
aws_cred_file=".aws/credentials"

### Change until here...

#Check how many aws cli profiles are present
awscli_profiles=(`gawk 'ORS=" "{ if (match($0,/\[([^)]+)\]/,m));gsub(/\[]/,"");print m[1] }' $aws_cred_file`)

#Query current address from router
current_address=`sshpass -e ssh -oBatchMode=no "$mikrotik_user"@"$mikrotik_addr" -q "/ip address print" | grep $mikrotik_dev_name | awk -F " " '{print $3}'`

#Query last address from log file;
if [ ! -f ./ip_address_list ]; then
    touch ./ip_address_list
    echo "23234545;364367676" > ./ip_address_list
else
    last_address=`tail -1 ./ip_address_list| awk -F";" '{print $2}'`
fi

echo Current_Address: $current_address
echo Last_Address: $last_address

get_time=$(date +"%Y-%m-%d_%H-%M-%S")

if [ "$current_address" == "$last_address" ]; then
 echo "No update required, IP address has not changed"
 exit;
else
  #Looping throught all aws cli profiles
  for awscli_profs in "${awscli_profiles[@]}";
  do
    #Getting all Security Group(s)
    sg_groups=( `aws ec2 describe-security-groups --profile $awscli_profs | gawk '{ if (match($0,/sg-[A-Za-z0-9]+/,m)) print m[0] }'| awk '!seen[$0]++' | awk 'ORS=" "{print $1}'`)

      #Looping throught all security groups in that profile
      for groupid in "${sg_groups[@]}";
        do
        #remove the old group since awscli doesn`t allow updating the rule itself
        aws ec2 revoke-security-group-ingress --profile $awscli_profs --group-id $groupid --protocol tcp --port $port_num --cidr $last_address;
        #create the new rule with the latest IP address
        aws ec2 authorize-security-group-ingress --profile $awscli_profs --group-id $groupid --ip-permissions '[{"IpProtocol": "tcp", "FromPort": '$port_num', "ToPort": '$port_num', "IpRanges": [{"CidrIp": "'$current_address'", "Description": "'$rule_desc'"}]}]';
      done;

  done;
 #write the entry into the log file so you can track how otfen and what addresses you get
 echo $get_time";"$current_address >> ./ip_address_list;
fi;
