#!/bin/bash

VPCS=$1
if [[ -z $VPCS ]]; then
    VPCS=$(cat -)
fi
if [[ -z ${VPCS} ]]; then
    echo "Usage: delete-vpc-flow-logs.sh <VPC_NAME,VPC_NAME>"
    exit 1
fi

VPCFLOW_ROLE_NAME="VpcFlow_CloudWatchLogs_Role"
VPCFLOW_POLICY_NAME="VpcFlow_CloudWatchLogs_Policy"
VPCFLOW_LOG_GROUP="CloudWatch/VPCLogGroup"

read -p "Do you want to delete Role, Policy and Log Group? " -n 1 -r </dev/tty
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting ${VPCFLOW_POLICY_NAME}"
    aws iam delete-role-policy --role-name ${VPCFLOW_ROLE_NAME} --policy-name ${VPCFLOW_POLICY_NAME} >> ./delete-vpc-flow-logs.log 2>&1 

    echo "Deleting ${VPCFLOW_ROLE_NAME}"
    aws iam delete-role --role-name ${VPCFLOW_ROLE_NAME} >> ./delete-vpc-flow-logs.log 2>&1 

    echo "Deleting ${VPCFLOW_LOG_GROUP}"
    aws logs delete-log-group --log-group-name ${VPCFLOW_LOG_GROUP} >> ./delete-vpc-flow-logs.log 2>&1 
fi

vpcs=$(echo $VPCS | tr "," "\n")
for vpc in ${vpcs}
do
    echo "Deleting Flow Logs for ${vpc}"
    aws ec2 delete-flow-logs --flow-log-ids $(aws ec2 describe-flow-logs --filter "Name=resource-id,Values=${vpc}" | jq -r ".FlowLogs[].FlowLogId") &>> ./delete-vpc-flow-logs.log 2>&1 
done

