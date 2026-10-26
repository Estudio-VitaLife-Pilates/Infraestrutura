import os
import shutil
import tempfile
import zipfile
from urllib.parse import urlparse
from pathlib import PurePosixPath
import urllib.request

import boto3

s3 = boto3.client("s3")

BUCKET_NAME = os.environ.get("BUCKET_NAME")
FILE_URL = os.environ.get(
    "FILE_URL",
    "https://svs.aids.gov.br/daent/cgdnt/vigitel/vigitel-2006-2024-peso-rake-csv.zip",
)
ZIP_FILE_NAME = PurePosixPath(urlparse(FILE_URL).path).name
PREFIX_BASE = os.environ.get("PREFIX_BASE", "vigitel/")


def lambda_handler(event, context):
    if PREFIX_BASE and not PREFIX_BASE.endswith("/"):
        PREFIX_BASE += "/"

    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            zip_path = os.path.join(temp_dir, "download.zip")

            with urllib.request.urlopen(FILE_URL, timeout=60) as response:
                with open(zip_path, "wb") as zip_file:
                    shutil.copyfileobj(response, zip_file)

            s3.upload_file(zip_path, BUCKET_NAME, PREFIX_BASE + "zip/" + ZIP_FILE_NAME)

            with zipfile.ZipFile(zip_path) as archive:
                csv_files = [
                    member
                    for member in archive.infolist()
                    if not member.is_dir() and member.filename.lower().endswith(".csv")
                ]

                if len(csv_files) != 1:
                    raise ValueError(
                        f"Esperado exatamente um CSV no ZIP; encontrados {len(csv_files)}."
                    )

                csv_member = csv_files[0]
                csv_name = PurePosixPath(csv_member.filename).name
                csv_path = os.path.join(temp_dir, "extracted.csv")

                with archive.open(csv_member) as source, open(csv_path, "wb") as target:
                    shutil.copyfileobj(source, target)

                s3.upload_file(csv_path, BUCKET_NAME, PREFIX_BASE + "csv/" + csv_name)

        return {
            "statusCode": 200,
            "body": (
                f"Arquivos {ZIP_FILE_NAME} e {csv_name} salvos com sucesso no S3."
            ),
        }

    except Exception as error:
        return {
            "statusCode": 500,
            "body": str(error)
        }
