#!/usr/bin/env python


import boto

#from boto.session import Session

# Get the service resource.

#session = Session(region_name='us-west-2')


dynamodb = boto.resource('dynamodb')


table = dynamodb.Table('MapiSettings')


response = table.get_item(
    Key={
        'Type': 'AwsAccountInfo',
        'Environment': 'dev'
    }
)
item = response['Item']
print(item)

