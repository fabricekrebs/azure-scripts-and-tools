#!/usr/bin/env python3
"""
Azure Batch Script: Convert JPG to PNG from Azure Blob Storage
Supports parallel processing across multiple nodes.
Each task processes a subset of files based on task-id and total-tasks.
"""

import os
import sys
import argparse
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from PIL import Image
from io import BytesIO


def get_blob_service_client():
    """
    Create and return a BlobServiceClient using either:
    1. Managed Identity (recommended for Azure Batch)
    2. Connection string from environment variable (fallback)
    """
    connection_string = os.getenv('AZURE_STORAGE_CONNECTION_STRING')
    storage_account_name = os.getenv('AZURE_STORAGE_ACCOUNT_NAME')
    
    # Try Managed Identity first (recommended)
    if storage_account_name and not connection_string:
        print(f"Authenticating with Managed Identity to storage account: {storage_account_name}")
        account_url = f"https://{storage_account_name}.blob.core.windows.net"
        credential = DefaultAzureCredential()
        return BlobServiceClient(account_url=account_url, credential=credential)
    
    # Fallback to connection string
    elif connection_string:
        print("Authenticating with connection string")
        return BlobServiceClient.from_connection_string(connection_string)
    
    else:
        raise ValueError(
            "Either AZURE_STORAGE_ACCOUNT_NAME (for Managed Identity) or "
            "AZURE_STORAGE_CONNECTION_STRING must be set"
        )


def list_and_sort_blobs(container_client):
    """
    List all blobs in the container and sort them alphabetically.
    
    Args:
        container_client: Azure Container Client
        
    Returns:
        list: Sorted list of blob names
    """
    blob_list = []
    
    print("Listing blobs in container...")
    for blob in container_client.list_blobs():
        blob_list.append(blob.name)
        print(f"  Found: {blob.name}")
    
    # Sort alphabetically
    blob_list.sort()
    print(f"\nTotal blobs found: {len(blob_list)}")
    
    return blob_list


def find_jpgs_for_task(blob_list, task_id=0, total_tasks=1):
    """
    Find JPG files assigned to this task based on task_id.
    Each task processes every Nth file where N = total_tasks.
    
    Args:
        blob_list: List of blob names (sorted)
        task_id: ID of this task (0-based)
        total_tasks: Total number of parallel tasks
        
    Returns:
        list: Names of JPG files assigned to this task
    """
    jpg_files = [blob for blob in blob_list if blob.lower().endswith(('.jpg', '.jpeg'))]
    
    # Assign files to this task (round-robin distribution)
    my_files = [jpg_files[i] for i in range(task_id, len(jpg_files), total_tasks)]
    
    return my_files


def convert_jpg_to_png(input_container_client, output_container_client, jpg_blob_name):
    """
    Download JPG, convert to PNG, and upload to output container.
    
    Args:
        input_container_client: Azure Container Client for input
        output_container_client: Azure Container Client for output
        jpg_blob_name: Name of the JPG blob to convert
    """
    print(f"\nProcessing: {jpg_blob_name}")
    
    # Download the JPG blob from input container
    blob_client = input_container_client.get_blob_client(jpg_blob_name)
    jpg_data = blob_client.download_blob().readall()
    print(f"  Downloaded {len(jpg_data)} bytes")
    
    # Convert JPG to PNG
    image = Image.open(BytesIO(jpg_data))
    print(f"  Image size: {image.size}, Mode: {image.mode}")
    
    # Save as PNG in memory
    png_buffer = BytesIO()
    image.save(png_buffer, format='PNG')
    png_data = png_buffer.getvalue()
    print(f"  Converted to PNG ({len(png_data)} bytes)")
    
    # Generate output blob name
    png_blob_name = os.path.splitext(jpg_blob_name)[0] + '.png'
    
    # Upload PNG to output container
    png_blob_client = output_container_client.get_blob_client(png_blob_name)
    png_blob_client.upload_blob(png_data, overwrite=True)
    print(f"  Uploaded to output container as: {png_blob_name}")
    
    return png_blob_name


def main():
    """
    Main function to execute the conversion process.
    """
    # Parse command-line arguments for parallel processing
    parser = argparse.ArgumentParser(description='Convert JPG to PNG with parallel processing support')
    parser.add_argument('--task-id', type=int, default=0, help='Task ID (0-based, for parallel processing)')
    parser.add_argument('--total-tasks', type=int, default=1, help='Total number of parallel tasks')
    args = parser.parse_args()
    
    try:
        # Get container names from environment variables or use defaults
        input_container_name = os.getenv('AZURE_STORAGE_INPUT_CONTAINER', 'images')
        output_container_name = os.getenv('AZURE_STORAGE_OUTPUT_CONTAINER', 'converted')
        
        print(f"Starting Azure Blob Storage JPG to PNG conversion")
        print(f"Task: {args.task_id + 1}/{args.total_tasks}")
        print(f"Input Container: {input_container_name}")
        print(f"Output Container: {output_container_name}\n")
        
        # Create blob service client
        blob_service_client = get_blob_service_client()
        
        # Get container clients
        input_container_client = blob_service_client.get_container_client(input_container_name)
        output_container_client = blob_service_client.get_container_client(output_container_name)
        
        # Check if input container exists
        if not input_container_client.exists():
            print(f"Error: Input container '{input_container_name}' does not exist")
            sys.exit(1)
        
        # Create output container if it doesn't exist
        if not output_container_client.exists():
            print(f"Creating output container '{output_container_name}'...")
            output_container_client.create_container()
            print(f"Output container created successfully")
        
        # List and sort blobs from input container
        blob_list = list_and_sort_blobs(input_container_client)
        
        if not blob_list:
            print("No blobs found in container")
            sys.exit(0)
        
        # Find JPG files assigned to this task
        my_jpg_files = find_jpgs_for_task(blob_list, args.task_id, args.total_tasks)
        
        if not my_jpg_files:
            print(f"No JPG files assigned to task {args.task_id}")
            sys.exit(0)
        
        print(f"\nFiles assigned to this task: {len(my_jpg_files)}")
        for idx, jpg_file in enumerate(my_jpg_files, 1):
            print(f"  [{idx}/{len(my_jpg_files)}] {jpg_file}")
        
        print(f"\nStarting conversions...")
        
        # Convert all assigned JPG files to PNG
        converted_files = []
        for idx, jpg_file in enumerate(my_jpg_files, 1):
            print(f"\n[{idx}/{len(my_jpg_files)}] Processing: {jpg_file}")
            png_file = convert_jpg_to_png(input_container_client, output_container_client, jpg_file)
            converted_files.append(png_file)
        
        print(f"\n✓ All conversions completed successfully!")
        print(f"  Total files processed: {len(converted_files)}")
        print(f"  Input:  {input_container_name}/")
        print(f"  Output: {output_container_name}/")
        
    except Exception as e:
        print(f"\n✗ Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
