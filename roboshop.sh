#!/bin/bash

AMI_ID="ami-0220d79f3f480ecf5"
SG_ID="sg-02b2c0c8175091ab8" # replace with your SG ID
INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
ZONE_ID="Z04626924Z2WBLM8PDBQ" # replace with your ZONE ID
DOMAIN_NAME="kimidi.site" # replace with your domain

for instance in ${INSTANCES[@]}
#for instance in $@
do
    INSTANCE_ID=$(aws ec2 run-instances --image-id ami-0220d79f3f480ecf5 --instance-type t3.micro --security-group-ids sg-02b2c0c8175091ab8 --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$instance}]" --query "Instances[0].InstanceId" --output text)
    if [ $instance != "frontend" ]
    then
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
        RECORD_NAME="$DOMAIN_NAME"
    fi
    echo "$instance IP address: $IP"