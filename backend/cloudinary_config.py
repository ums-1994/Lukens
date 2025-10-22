import cloudinary
import cloudinary.uploader
import os
from dotenv import load_dotenv

load_dotenv()

# Configure Cloudinary
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

def upload_to_cloudinary(file_path: str, resource_type: str = "auto", folder: str = "proposal_builder"):
    """
    Upload a file to Cloudinary
    
    Args:
        file_path: Path to the file to upload
        resource_type: Type of resource (auto, image, video, raw)
        folder: Cloudinary folder path
    
    Returns:
        dict: Upload response with url and public_id
    """
    try:
        result = cloudinary.uploader.upload(
            file_path,
            resource_type=resource_type,
            folder=folder,
            access_mode="public"  # Public access - visible to all
        )
        return {
            "success": True,
            "url": result.get("secure_url"),
            "public_id": result.get("public_id"),
            "resource_type": result.get("resource_type"),
            "width": result.get("width"),
            "height": result.get("height"),
            "size": result.get("bytes"),
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

def get_cloudinary_upload_signature(public_id: str):
    """
    Generate a signed upload signature for frontend direct uploads
    Allows Flutter to upload directly to Cloudinary securely
    """
    import time
    import hashlib
    
    timestamp = int(time.time())
    
    params = {
        "public_id": public_id,
        "timestamp": timestamp,
        "folder": "proposal_builder",
        "access_mode": "public"
    }
    
    # Create signing string
    signing_string = "&".join([f"{k}={v}" for k, v in sorted(params.items())])
    signing_string += os.getenv("CLOUDINARY_API_SECRET")
    
    signature = hashlib.sha1(signing_string.encode()).hexdigest()
    
    return {
        "signature": signature,
        "timestamp": timestamp,
        **params
    }

def delete_from_cloudinary(public_id: str, resource_type: str = "image"):
    """
    Delete a file from Cloudinary
    """
    try:
        result = cloudinary.uploader.destroy(
            public_id,
            resource_type=resource_type
        )
        return {"success": True, "result": result}
    except Exception as e:
        return {"success": False, "error": str(e)}