#!/usr/bin/env python


import boto3

#from boto3.session import Session

# Get the service resource.

#session = Session(region_name='us-west-2')


dynamodb = boto3.resource('dynamodb')


table = dynamodb.Table('MapiSettings')


response = table.get_item(
    Key={
        'Type': 'AwsAccountInfo',
        'Environment': 'dev'
    }
)
item = response['Item']
print(item)

