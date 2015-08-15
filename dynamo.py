#!/usr/bin/env python


import boto.dynamodb

conn = boto.dynamodb.connect_to_region('us-west-2')

table = conn.get_table('MapiSettings')

item = table.get_item(
        hash_key='AwsAccountInfo',
        range_key='dev'
    )
print(item)

#from boto3.session import Session

# Get the service resource.

#session = Session(region_name='us-west-2')



#dynamodb = boto.resource('dynamodb')

#table = dynamodb.Table('MapiSettings')


#response = table.get_item(
    #Key={
        #'Type': 'AwsAccountInfo',
        #'Environment': 'dev'
    #}
#)
#item = response['Item']
#print(item)

