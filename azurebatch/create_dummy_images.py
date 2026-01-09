#!/usr/bin/env python3
"""
Create dummy JPG images and upload them to Azure Blob Storage
Useful for testing the parallel image conversion pipeline
"""

import os
import sys
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
import random


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


def create_dummy_image(width=800, height=600, text="", bg_color=None):
    """
    Create a dummy JPG image with specified dimensions and text.
    
    Args:
        width: Image width in pixels
        height: Image height in pixels
        text: Text to display on the image
        bg_color: Background color tuple (R, G, B) or None for random
        
    Returns:
        BytesIO: Image data as bytes
    """
    # Random background color if not specified
    if bg_color is None:
        bg_color = (
            random.randint(50, 200),
            random.randint(50, 200),
            random.randint(50, 200)
        )
    
    # Create image
    image = Image.new('RGB', (width, height), bg_color)
    draw = ImageDraw.Draw(image)
    
    # Add some random shapes
    for _ in range(5):
        x1 = random.randint(0, width)
        y1 = random.randint(0, height)
        x2 = random.randint(0, width)
        y2 = random.randint(0, height)
        # Ensure coordinates are in correct order
        x1, x2 = min(x1, x2), max(x1, x2)
        y1, y2 = min(y1, y2), max(y1, y2)
        color = (random.randint(0, 255), random.randint(0, 255), random.randint(0, 255))
        draw.rectangle([x1, y1, x2, y2], outline=color, width=3)
    
    # Add text if provided
    if text:
        # Calculate text position (centered)
        # Use default font since custom fonts may not be available
        text_bbox = draw.textbbox((0, 0), text)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        text_x = (width - text_width) // 2
        text_y = (height - text_height) // 2
        
        # Draw text with outline for better visibility
        outline_color = (0, 0, 0)
        text_color = (255, 255, 255)
        for adj_x in [-2, 0, 2]:
            for adj_y in [-2, 0, 2]:
                draw.text((text_x + adj_x, text_y + adj_y), text, fill=outline_color)
        draw.text((text_x, text_y), text, fill=text_color)
    
    # Save to bytes
    buffer = BytesIO()
    image.save(buffer, format='JPEG', quality=85)
    buffer.seek(0)
    return buffer


def upload_dummy_images(container_client, num_images=20, prefix="test-image"):
    """
    Create and upload dummy images to blob storage.
    
    Args:
        container_client: Azure Container Client
        num_images: Number of images to create
        prefix: Filename prefix
    """
    print(f"\nCreating and uploading {num_images} dummy JPG images...")
    print(f"Prefix: {prefix}")
    print("")
    
    for i in range(num_images):
        filename = f"{prefix}-{i:03d}.jpg"
        text = f"Image #{i+1}"
        
        # Create image
        image_data = create_dummy_image(
            width=800,
            height=600,
            text=text
        )
        
        # Upload to blob storage
        blob_client = container_client.get_blob_client(filename)
        blob_client.upload_blob(image_data, overwrite=True)
        
        # Get size
        size_kb = len(image_data.getvalue()) / 1024
        
        print(f"  ✓ Uploaded: {filename} ({size_kb:.1f} KB)")
    
    print(f"\n✅ Successfully created {num_images} dummy images!")


def main():
    """
    Main function to execute the dummy image creation.
    """
    import argparse
    
    parser = argparse.ArgumentParser(description='Create dummy JPG images in Azure Blob Storage')
    parser.add_argument('--count', type=int, default=20, help='Number of images to create (default: 20)')
    parser.add_argument('--prefix', type=str, default='test-image', help='Filename prefix (default: test-image)')
    parser.add_argument('--container', type=str, help='Container name (overrides env variable)')
    args = parser.parse_args()
    
    try:
        # Get container name from argument or environment variable
        container_name = args.container or os.getenv('AZURE_STORAGE_INPUT_CONTAINER', 'images')
        
        print("=" * 50)
        print("Azure Blob Storage - Dummy Image Creator")
        print("=" * 50)
        print(f"Container: {container_name}")
        print(f"Count: {args.count}")
        print(f"Prefix: {args.prefix}")
        print("")
        
        # Create blob service client
        blob_service_client = get_blob_service_client()
        
        # Get container client
        container_client = blob_service_client.get_container_client(container_name)
        
        # Check if container exists, create if not
        if not container_client.exists():
            print(f"Container '{container_name}' does not exist. Creating...")
            container_client.create_container()
            print(f"✓ Container created")
        
        # Upload dummy images
        upload_dummy_images(container_client, num_images=args.count, prefix=args.prefix)
        
        print("")
        print("You can now run the parallel conversion:")
        print(f"  ./deploy_parallel.sh")
        
    except Exception as e:
        print(f"\n✗ Error: {str(e)}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
