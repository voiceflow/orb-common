#!/bin/bash

# Get the public IP of the current CircleCI runner
PUBLIC_IP=$(curl ipinfo.io/ip)

# Remove ingress rule from the security group
aws ec2 revoke-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $PUBLIC_IP/24
