#!/usr/bin/env python3
"""
Check Cloudinary resources and folders using .env credentials
"""

import os
from dotenv import load_dotenv
import cloudinary
from cloudinary.api import resources as api_resources, subfolders as api_subfolders

# Load environment variables from backend/.env
load_dotenv('backend/.env')

# Get Cloudinary credentials from environment
cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME')
api_key = os.getenv('CLOUDINARY_API_KEY')
api_secret = os.getenv('CLOUDINARY_API_SECRET')

if not all([cloud_name, api_key, api_secret]):
    print("❌ Missing Cloudinary credentials in .env file")
    print("Required: CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET")
    exit(1)

# Configure Cloudinary
cloudinary.config(
    cloud_name=cloud_name,
    api_key=api_key,
    api_secret=api_secret
)

print('All resources in your account:')
try:
    resources = api_resources(type='upload', max_results=50)
    for resource in resources.get('resources', []):
        public_id = resource.get('public_id')
        format = resource.get('format')
        folder = resource.get('folder', 'root')
        resource_type = resource.get('resource_type', 'unknown')
        print(f'  {folder}/{public_id}.{format} (type: {resource_type})')
except Exception as e:
    print(f'  Error: {e}')

print('\nFolders:')
try:
    folders = api_subfolders()
    for folder in folders.get('folders', []):
        print(f'  {folder.get("name")} (path: {folder.get("path")})')
except Exception as e:
    print(f'  Error listing folders: {e}')
