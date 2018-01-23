# AWS Cloudtrail

## Usage

```
NOTIFICATION_EMAIL="email1@domain.com,email2@domain.com" AWS_REGION=xxx AWS_ACCOUNT_ID=xxx create-default-cloud-trail.sh
```

## Description step by step

1. Create a Trail with new bucket and enable for all region

```
aws cloudtrail create-subscription --name=${TRAIL_NAME} --s3-new-bucket=${TRAIL_NAME}-bucket --sns-new-topic=${TRAIL_NAME}-sns-topic
```

2. Update ACL with READ/WRITE permission for the new bucket and enable logging

```
aws s3api put-bucket-acl --bucket ${TRAIL_NAME}-bucket --grant-write "uri=http://acs.amazonaws.com/groups/s3/LogDelivery" --grant-read-acp "uri=http://acs.amazonaws.com/groups/s3/LogDelivery"
aws s3api put-bucket-logging --bucket ${TRAIL_NAME}-bucket --bucket-logging-status "{\"LoggingEnabled\": { \"TargetBucket\": \"${TRAIL_NAME}-bucket\", \"TargetPrefix\": \"\" }}"
```

3. Create KMS key with alias for Trail log encryption using predefined policy for giving
   rights and enable key rotation

```
cat ./config/kms-cloudtrail-policy.json | sed s/{{AWS_REGION}}/${AWS_REGION}/g | sed s/{{AWS_ACCOUNT_ID}}/${AWS_ACCOUNT_ID}/g > tmp.json
KMS_KEYID=$(aws kms create-key --policy file://./tmp.json | jq -r ".KeyMetadata.KeyId")
rm tmp.json
aws kms create-alias --alias-name "alias/${TRAIL_NAME}-kms-key" --target-key-id ${KMS_KEYID}
aws kms enable-key-rotation --key-id ${KMS_KEYID}
```

4. Create Log Group to centralized generated logs

```
aws logs create-log-group --log-group-name "CloudTrail/${TRAIL_NAME}LogGroup"
```

5. Generate CloudFormation template to generate FilterMetrics and Alarm for
   Logs

```
cat ./config/CloudWatch_Alarms_for_CloudTrail_API_Activity.json | sed s/{{LOG_GROUP}}/${TRAIL_NAME}LogGroup/g > tmp.json
aws cloudformation create-stack --stack-name CloudWatchAlarmsForCloudTrail --template-body file://./tmp.json --parameters "ParameterKey=Email,ParameterValue=${NOTIFICATION_EMAIL}"
rm tmp.json
```

6. Create CloudWatch role to allow communication between CloudWatch and
   CloudTrail

```
aws iam create-role --role-name CloudTrail_CloudWatchLogs_Role --assume-role-policy-document '{ "Version": "2012-10-17", "Statement": [{ "Sid": "", "Effect": "Allow", "Principal": { "Service": "cloudtrail.amazonaws.com" }, "Action": "sts:AssumeRole" }]}' | jq -r .Role.Arn
LOG_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/CloudTrail_CloudWatchLogs_Role"
cat ./config/cloudwatchlogrole-policy.json | sed s/{{AWS_REGION}}/${AWS_REGION}/g | sed s/{{AWS_ACCOUNT_ID}}/${AWS_ACCOUNT_ID}/g | sed s/{{LOG_GROUP}}/${TRAIL_NAME}LogGroup/g > tmp.json
aws iam put-role-policy --role-name  CloudTrail_CloudWatchLogs_Role --policy-name CloudTrail_CloudWatchLogs_Policy --policy-document file://tmp.json
rm tmp.json
```

7. Wait few seconds to let the role be activated

```
sleep 25
```

8. Enable Multi Region, Encryption, Log file validation and CloudWatch for the
   trail

```
aws cloudtrail update-trail --name ${TRAIL_NAME} --is-multi-region-trail --kms-key-id ${KMS_KEYID} --enable-log-file-validation --cloud-watch-logs-log-group-arn "${LOG_GROUP_ARN}" --cloud-watch-logs-role-arn "${LOG_ROLE_ARN}"
```

9. Monitor s3 event

```
aws cloudtrail put-event-selectors --trail-name ${TRAIL_NAME} --event-selectors '[{ "ReadWriteType": "All", "IncludeManagementEvents":true, "DataResources": [{ "Type": "AWS::S3::Object", "Values": ["arn:aws:s3"] }] }]'
```
