# MinIO FAQs

## 1 Unable to access the server: <server_url>

This error typically occurs when the MinIO client is unable to connect to the server. To resolve this issue, you can try the following actions:

1. Check if the network connection is working properly.
2. Verify if the server URL is correct.

## 2 Bucket not found: <bucket_name>

This error usually occurs when the specified bucket does not exist. To resolve this issue, you can try the following actions:

1. Confirm if the bucket name is correct.
2. Check if the bucket exists on the MinIO server.
3. Ensure that the access key and secret key being used have the necessary permissions to access the bucket.

## 3 Access denied

This error typically occurs when access is denied. To resolve this issue, you can try the following actions:

1. Confirm if the access key and secret key being used are correct.
2. Ensure that the access key and secret key have the required permissions to access the requested resource.

## 4 Insufficient data for block

This error usually occurs when there is not enough data to create a complete block during file upload. To resolve this issue, you can try the following actions:

1. Confirm if the MinIO server has sufficient disk space to store the uploaded data.
2. Configure an appropriate lifecycle policy to delete expired objects and reduce unnecessary storage usage.

## 5 Bucket not empty

This error typically occurs when attempting to delete a non-empty bucket. To resolve this issue, you can try the following actions:

Ensure that all objects within the bucket have been deleted. If there are still objects in the bucket, delete them before attempting to delete the bucket.
