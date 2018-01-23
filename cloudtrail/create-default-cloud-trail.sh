#!/bin/sh 
if [[ -z ${NOTIFICATION_EMAIL} ]] || [[ -z ${AWS_REGION} ]] || [[ -z ${AWS_ACCOUNT_ID} ]]; then
    echo "Usage NOTIFICATION_EMAIL=xxx AWS_REGION=xxx AWS_ACCOUNT_ID=xxx create-default-cloud-trail.sh"
    exit 1
fi
 
if [[ -z $1 ]]; then
    TRAIL_NAME=$(head -c 64 /dev/urandom | tr -dc a-z0-9)
fi

set -eu
echo Using ${TRAIL_NAME} Trail Name

aws cloudtrail create-subscription --name=${TRAIL_NAME} --s3-new-bucket=${TRAIL_NAME}-bucket --sns-new-topic=${TRAIL_NAME}-sns-topic
aws s3api put-bucket-acl --bucket ${TRAIL_NAME}-bucket --grant-write "uri=http://acs.amazonaws.com/groups/s3/LogDelivery" --grant-read-acp "uri=http://acs.amazonaws.com/groups/s3/LogDelivery"
aws s3api put-bucket-logging --bucket ${TRAIL_NAME}-bucket --bucket-logging-status "{\"LoggingEnabled\": { \"TargetBucket\": \"${TRAIL_NAME}-bucket\", \"TargetPrefix\": \"\" }}"
cat ./config/kms-cloudtrail-policy.json | sed s/{{AWS_REGION}}/${AWS_REGION}/g | sed s/{{AWS_ACCOUNT_ID}}/${AWS_ACCOUNT_ID}/g > tmp.json
KMS_KEYID=$(aws kms create-key --policy file://./tmp.json | jq -r ".KeyMetadata.KeyId")
rm tmp.json
aws kms create-alias --alias-name "alias/${TRAIL_NAME}-kms-key" --target-key-id ${KMS_KEYID}
aws kms enable-key-rotation --key-id ${KMS_KEYID}
aws logs create-log-group --log-group-name "CloudTrail/${TRAIL_NAME}LogGroup"
cat ./config/CloudWatch_Alarms_for_CloudTrail_API_Activity.json | sed s/{{LOG_GROUP}}/${TRAIL_NAME}LogGroup/g > tmp.json
aws cloudformation create-stack --stack-name CloudWatchAlarmsForCloudTrail --template-body file://./tmp.json --parameters "ParameterKey=Email,ParameterValue=${NOTIFICATION_EMAIL}"
rm tmp.json
LOG_GROUP_ARN=$(aws logs describe-log-groups --log-group-name-prefix CloudTrail/${TRAIL_NAME}LogGroup | jq -r ".logGroups[0].arn")

aws iam create-role --role-name CloudTrail_CloudWatchLogs_Role --assume-role-policy-document '{ "Version": "2012-10-17", "Statement": [{ "Sid": "", "Effect": "Allow", "Principal": { "Service": "cloudtrail.amazonaws.com" }, "Action": "sts:AssumeRole" }]}' | jq -r .Role.Arn
LOG_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/CloudTrail_CloudWatchLogs_Role"
cat ./config/cloudwatchlogrole-policy.json | sed s/{{AWS_REGION}}/${AWS_REGION}/g | sed s/{{AWS_ACCOUNT_ID}}/${AWS_ACCOUNT_ID}/g | sed s/{{LOG_GROUP}}/${TRAIL_NAME}LogGroup/g > tmp.json
aws iam put-role-policy --role-name  CloudTrail_CloudWatchLogs_Role --policy-name CloudTrail_CloudWatchLogs_Policy --policy-document file://tmp.json
rm tmp.json

echo Waiting 25 sec
sleep 25

aws cloudtrail update-trail --name ${TRAIL_NAME} --is-multi-region-trail --kms-key-id ${KMS_KEYID} --enable-log-file-validation --cloud-watch-logs-log-group-arn "${LOG_GROUP_ARN}" --cloud-watch-logs-role-arn "${LOG_ROLE_ARN}"
aws cloudtrail put-event-selectors --trail-name ${TRAIL_NAME} --event-selectors '[{ "ReadWriteType": "All", "IncludeManagementEvents":true, "DataResources": [{ "Type": "AWS::S3::Object", "Values": ["arn:aws:s3"] }] }]'
