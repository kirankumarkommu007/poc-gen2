FROM python:3.12-slim

WORKDIR /function

COPY app/requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt --target /function

COPY app/ ./

# Set environment variables (for local testing)
ENV BUCKET_NAME="your-test-bucket"
ENV COLLECTION_NAME="test-uploads"
ENV FIRESTORE_DB="(default)"

ENV FUNCTION_TARGET=upload_file
ENV PORT=8080

EXPOSE 8080

CMD ["python", "-m", "functions_framework", "--target=upload_file", "--port=8080"]
