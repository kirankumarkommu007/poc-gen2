import os
import functions_framework
from google.cloud import storage, firestore
from datetime import datetime
from flask import request

@functions_framework.http
def upload_file(request):
    if request.method != "POST":
        return {"error": "Only POST allowed"}, 405

    uploaded_by = request.form.get("uploadedBy")
    file = request.files.get("file")

    if not file or not uploaded_by:
        return {"error": "Missing uploadedBy or file"}, 400

    # Load environment variables
    bucket_name = os.environ.get("BUCKET_NAME")
    collection_name = os.environ.get("COLLECTION_NAME")

    if not bucket_name or not collection_name:
        return {"error": "Missing environment configuration"}, 500

    # Initialize clients
    storage_client = storage.Client()
    firestore_client = firestore.Client()

    # Upload file to bucket
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file.filename)
    blob.upload_from_file(file.stream, content_type=file.content_type)

    # Add metadata to Firestore
    doc_ref = firestore_client.collection(collection_name).document()
    doc_ref.set({
        "filename": file.filename,
        "uploadedBy": uploaded_by,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })

    return {"message": f"File {file.filename} uploaded successfully!"}, 200
