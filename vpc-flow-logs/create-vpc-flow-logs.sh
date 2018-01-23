#!/bin/bash
VPCS=$1
if [[ -z $VPCS ]]; then
    VPCS=$(cat -)
fi
if [[ -z ${VPCS} ]]; then
    echo "Usage: create-vpc-flow-logs.sh <VPC_NAME,VPC_NAME>"
    exit 1
fi

VPCFLOW_ROLE_NAME="VpcFlow_CloudWatchLogs_Role"
VPCFLOW_POLICY_NAME="VpcFlow_CloudWatchLogs_Policy"
VPCFLOW_LOG_GROUP="CloudWatch/VPCLogGroup"

read -p "Do you want to create Role, Policy and Log Group? " -n 1 -r </dev/tty
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating ${VPCFLOW_ROLE_NAME}"
    aws iam create-role --role-name ${VPCFLOW_ROLE_NAME} --assume-role-policy-document file://./config/vpcflow-trust-relationship.json >> ./create-vpc-flow-logs.log 2>&1 

    echo "Creating ${VPCFLOW_POLICY_NAME}"
    aws iam put-role-policy --role-name ${VPCFLOW_ROLE_NAME} --policy-name ${VPCFLOW_POLICY_NAME} --policy-document file://./config/vpcflow-role-policy.json >> ./create-vpc-flow-logs.log 2>&1 

    echo "Creating ${VPCFLOW_LOG_GROUP}"
    aws logs create-log-group --log-group-name ${VPCFLOW_LOG_GROUP} &> ./create-vpc-flow-logs.log 
fi

vpcs=$(echo $VPCS | tr "," "\n")
for vpc in ${vpcs}
do
    echo "Creating Flow Logs for $vpc"
    ROLE_ARN=$(aws iam get-role --role-name ${VPCFLOW_ROLE_NAME} | jq -r '.Role.Arn')
    aws ec2 create-flow-logs --resource-ids $vpc --deliver-logs-permission-arn ${ROLE_ARN} --resource-type "VPC" --traffic-type "REJECT" --log-group-name ${VPCFLOW_LOG_GROUP} >> ./create-vpc-flow-logs.log 2>&1
done

