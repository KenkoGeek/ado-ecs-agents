import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs_client = boto3.client('ecs')

def lambda_handler(event, context):
    try:
        # Parse webhook payload
        body = json.loads(event['body'])
        
        # Check if it's a job queued event
        event_type = body.get('eventType', '')
        
        if event_type == 'ms.vss-distributedtask.job-queued':
            logger.info("Job queued event received")
            scale_up()
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Scaling up ECS service'})
            }
        
        elif event_type == 'ms.vss-distributedtask.job-completed':
            logger.info("Job completed event received")
            # Cleanup will be handled by scheduled function
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Job completed acknowledged'})
            }
        
        else:
            logger.info(f"Unhandled event type: {event_type}")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Event acknowledged'})
            }
            
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def scale_up():
    cluster_name = os.environ['ECS_CLUSTER']
    service_name = os.environ['ECS_SERVICE']
    
    # Get current service status
    response = ecs_client.describe_services(
        cluster=cluster_name,
        services=[service_name]
    )
    
    current_desired = response['services'][0]['desiredCount']
    new_desired = current_desired + 1
    
    # Update service desired count
    ecs_client.update_service(
        cluster=cluster_name,
        service=service_name,
        desiredCount=new_desired
    )
    
    logger.info(f"Scaled ECS service from {current_desired} to {new_desired} tasks")