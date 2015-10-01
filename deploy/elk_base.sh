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

####################################################################
# Create the base image
# Script is expected to run from the Jenkins workspace directory
####################################################################
#set account permissions on the AMI
if [ "${Environment}" == "Dev" ]; then
  ACCNUMBER="425555124585"
  SUBNETID="subnet-d26ee5b7"
  VPCID="vpc-5d9e2c38"
  Environment="dev"
elif [ "${Environment}" == "QA" ]; then
  ACCNUMBER="337683724535"
  SUBNETID="subnet-73961b04"
  VPCID="vpc-dd1e89b8"
  Environment="qa"
else
  echo "Account not found."
  exit 1
fi

echo "ACCNUMBER='${ACCNUMBER}'"

aws sts assume-role --role-arn=arn:aws:iam::${ACCNUMBER}:role/User --role-session-name="userRole" --region=${REGION} > ${WORKSPACE}/credentials.txt
export AWS_SECRET_ACCESS_KEY=`grep SecretAccessKey credentials.txt |cut -d"\"" -f4`
export AWS_SECURITY_TOKEN=`grep SessionToken credentials.txt |cut -d"\"" -f4`
export AWS_ACCESS_KEY_ID=`grep AccessKeyId credentials.txt |cut -d"\"" -f4`

# Get the IP Address of this machine
JENKINS_SLAVE_IP=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>&1`
# Create temporary security group to allow Jenkins SSH communication to EC2 instance in RDC
aws ec2 create-security-group --group-name "mAPI-JenkinsSSH" --vpc-id ${VPCID} --description "mAPI-JenkinsSSH" --region us-west-2 2>&1 | tee sg_create_output.txt
#Get the group id of above
export SG_GROUP_ID_TEMPSSH=`grep GroupId sg_create_output.txt | cut -d":" -f 2 | cut -d"\"" -f 2`
# Add ingress rule to SG
aws ec2 authorize-security-group-ingress --region us-west-2 --group-id ${SG_GROUP_ID_TEMPSSH} --protocol tcp --port 22 --cidr ${JENKINS_SLAVE_IP}/32


cd deploy

cat <<HERE  > aws.config
export AWS_ENVIRONMENT=${Environment}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_SECURITY_TOKEN=${AWS_SECURITY_TOKEN}
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
HERE

aws s3 cp --region ${REGION} s3://moverdc-mapi-config/logstash-forwarder-dev.crt .
aws s3 cp --region ${REGION} s3://moverdc-mapi-config/logstash-forwarder-dev.key .


####################
# Build The Image
####################
echo "packer build -var 'BASEAMI=${BASE_AMI_ID}' -var 'VPCID=${VPCID}' -var 'SUBNETID=${SUBNETID}' ${WORKSPACE}/Mobile-API/deploy/node-packer.json 2>&1 | tee output.txt"
packer build -color=false \
  -var "BASEAMI=${BASE_AMI_ID}" \
  -var "VPCID=${VPCID}" \
  -var "SUBNETID=${SUBNETID}" \
  -var "ENVIRONMENT=${Environment}" \
  -var "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" \
  -var "AWS_SECURITY_TOKEN=${AWS_SECURITY_TOKEN}" \
  -var "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" \
  -var "SG_GROUP_ID_TEMPSSH=${SG_GROUP_ID_TEMPSSH}" \
    logstash-kibana-packer.json 2>&1 | tee output.txt

# Delete our temporary security group
delete_temp_ag ${SG_GROUP_ID_TEMPSSH}
unset SG_GROUP_ID_TEMPSSH

ERROUT=`grep -e "Error" -e "Failed to parse template:" output.txt` || true

if [ -z "${ERROUT}" ]; then
  echo "exposing AMI..."
else
  echo "${ERROUT}: build failed\n"
  exit 1
fi

#get the ami id
export AMI_ID=`tail -2 output.txt | head -2 | awk 'match($0, /ami-.*/) { print substr($0, RSTART, RLENGTH) }'`

cd ${WORKSPACE}

echo "...ID: ${AMI_ID}"


