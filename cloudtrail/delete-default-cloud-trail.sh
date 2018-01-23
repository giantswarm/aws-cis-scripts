#!/bin/sh 

if [[ -z $1 ]] || [[ -z ${AWS_REGION} ]] || [[ -z ${AWS_ACCOUNT_ID} ]]; then
    echo "Usage AWS_REGION=xxx AWS_ACCOUNT_ID=xxx delete-default-cloud-trail.sh <TRAIL_NAME>" 
    exit 1
fi

TRAIL_NAME=$1

aws cloudformation delete-stack --stack-name CloudWatchAlarmsForCloudTrail
aws iam delete-role-policy --role-name CloudTrail_CloudWatchLogs_Role --policy-name CloudTrail_CloudWatchLogs_Policy
aws iam delete-role --role-name CloudTrail_CloudWatchLogs_Role
aws logs delete-log-group --log-group-name "CloudTrail/${TRAIL_NAME}LogGroup"
KMS_ID=$(aws kms list-aliases --query "Aliases[?AliasName==\`alias/${TRAIL_NAME}-kms-key\`]" | jq -r ".[0].TargetKeyId")
aws kms schedule-key-deletion --key-id ${KMS_ID}
aws sns delete-topic --topic-arn "arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${TRAIL_NAME}-sns-topic"
aws cloudtrail delete-trail --name ${TRAIL_NAME}
aws s3api delete-bucket --bucket ${TRAIL_NAME}-bucket 



