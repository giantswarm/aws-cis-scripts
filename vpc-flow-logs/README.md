# AWS VPC Flow Logs

## Usage

```
AWS_PROFILE=adidas-playground-guest ./create-vpc-flow-logs.sh <VPC-NAME,VPC-NAME>
```

### Enable VPC Flow Logs for every vpc in a region

```
AWS_PROFILE=adidas-playground-guest aws ec2 describe-vpcs --query "Vpcs[].VpcId" | jq -r '.[]' | paste -s -d"," | AWS_PROFILE=adidas-playground-guest ./create-vpc-flow-logs.sh
```

## Description step by step

1. Create a role for managing VPC Flow

```
aws iam create-role --role-name ${VPCFLOW_ROLE_NAME} --assume-role-policy-document file://./config/vpcflow-trust-relationship.json
```

2. Add Policy to allow VPC-Flow management

```
aws iam put-role-policy --role-name ${VPCFLOW_ROLE_NAME} --policy-name ${VPCFLOW_POLICY_NAME} --policy-document file://./config/vpcflow-role-policy.json
```

3.  Create Log Group to centralized generated logs

```
aws logs create-log-group --log-group-name ${VPCFLOW_LOG_GROUP}
```

4. Create VPC Flow logs
```
ROLE_ARN=$(aws iam get-role --role-name ${VPCFLOW_ROLE_NAME} | jq -r '.Role.Arn')
aws ec2 create-flow-logs --resource-ids $vpc --deliver-logs-permission-arn ${ROLE_ARN} --resource-type "VPC" --traffic-type "REJECT" --log-group-name ${VPCFLOW_LOG_GROUP}
```

