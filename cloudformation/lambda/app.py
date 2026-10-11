import base64
import json
import os

import boto3

s3 = boto3.client("s3")
BUCKET_NAME = os.environ["BUCKET_NAME"]


def lambda_handler(event, context):
    query_params = event.get("queryStringParameters") or {}
    file_name = query_params.get("filename")

    if not file_name:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {
                    "error": "O parametro filename e obrigatorio na URL "
                    "(?filename=exemplo.txt)"
                }
            ),
        }

    try:
        body = event.get("body", "")
        if event.get("isBase64Encoded", False):
            file_content = base64.b64decode(body)
        else:
            file_content = body.encode("utf-8") if isinstance(body, str) else body

        s3.put_object(Bucket=BUCKET_NAME, Key=file_name, Body=file_content)

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {"message": f"Arquivo raw/{file_name} salvo com sucesso no S3!"}
            ),
        }
    except Exception as error:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(error)}),
        }
