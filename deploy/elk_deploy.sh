#!/usr/bin/env bash

# Always stop if the script fails
set -e

delete_temp_ag() {
    if [ -n $1 ]; then
        echo "Deleting security group: ${1}"
        # Delete the temp security group
        aws ec2 delete-security-group --region ${REGION} --group-id $1
    fi
}

# Cleanup if there is an error
trap 'delete_temp_ag $SG_GROUP_ID_TEMPSSH' ERR


####################
# Deploy The Code
# Script is expected to run from the Jenkins workspace directory
####################
#set account permissions on the AMI
if [ "${Environment}" == "Dev" ]; then
  ACCNUMBER="425555124585"
  SUBNETID="subnet-d26ee5b7"
  VPCID="vpc-5d9e2c38"
  Environment="dev"
  CLOUD_FORMATION_STACK="mAPI-Node-JS-Dev"
  BUCKET_NAME="mapi-cfg.rdc-dev.moveaws.com"
elif [ "${Environment}" == "QA" ]; then
  ACCNUMBER="337683724535"
  SUBNETID="subnet-73961b04"
  VPCID="vpc-dd1e89b8"
  CLOUD_FORMATION_STACK="mAPI-Node-JS-QA"
  Environment="qa"
  BUCKET_NAME="mapi-cfg.rdc-qa.moveaws.com"
else
  echo "Account not found."
  exit 1
fi

echo "ACCNUMBER='${ACCNUMBER}'"

aws sts assume-role --role-arn=arn:aws:iam::${ACCNUMBER}:role/User --role-session-name="userRole" --region=${REGION} > ${WORKSPACE}/credentials.txt
export AWS_SECRET_ACCESS_KEY=`grep SecretAccessKey credentials.txt |cut -d"\"" -f4`
export AWS_SECURITY_TOKEN=`grep SessionToken credentials.txt |cut -d"\"" -f4`
export AWS_ACCESS_KEY_ID=`grep AccessKeyId credentials.txt |cut -d"\"" -f4`


# make sure there is no existing mAPI-JenkinsSSH security group
export EXISTING_SG_GROUP_ID_TEMPSSH=`aws ec2 describe-security-groups --region ${REGION} --filters Name=group-name,Values='mAPI-JenkinsSSH' --query 'SecurityGroups[*].GroupId' --output text`
if [ ! -z ${EXISTING_SG_GROUP_ID_TEMPSSH} ]; then
    echo "Found existing mAPI-JenkinsSSH security group: ${EXISTING_SG_GROUP_ID_TEMPSSH}"
    delete_temp_ag ${EXISTING_SG_GROUP_ID_TEMPSSH}
fi

# Get the IP Address of this machine
JENKINS_SLAVE_IP=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>&1`
# Create temporary security group to allow Jenkins SSH communication to EC2 instance in RDC
aws ec2 create-security-group --group-name "mAPI-JenkinsSSH" --vpc-id ${VPCID} --description "mAPI-JenkinsSSH" --region ${REGION} 2>&1 | tee sg_create_output.txt
#Get the group id of above
export SG_GROUP_ID_TEMPSSH=`grep GroupId sg_create_output.txt | cut -d":" -f 2 | cut -d"\"" -f 2`
# Add ingress rule to SG
aws ec2 authorize-security-group-ingress --region ${REGION} --group-id ${SG_GROUP_ID_TEMPSSH} --protocol tcp --port 22 --cidr ${JENKINS_SLAVE_IP}/32

