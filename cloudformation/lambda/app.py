import os
import urllib.request
import boto3

s3 = boto3.client("s3")

BUCKET_NAME = os.environ["BUCKET_NAME"]
FILE_URL = os.environ["FILE_URL"]
FILE_NAME = os.environ.get("FILE_NAME", "arquivo.csv")


def lambda_handler(event, context):
    try:
        with urllib.request.urlopen(FILE_URL) as response:
            file_content = response.read()

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=FILE_NAME,
            Body=file_content
        )

        return {
            "statusCode": 200,
            "body": f"Arquivo {FILE_NAME} salvo com sucesso no S3."
        }

    except Exception as error:
        return {
            "statusCode": 500,
            "body": str(error)
        }
