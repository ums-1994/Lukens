"""
Test the upload endpoints directly
"""
import requests
import io

# Create a test file
test_content = b"This is a test document"
test_file = io.BytesIO(test_content)

print("=== Testing Upload Endpoints ===\n")

# Test /upload/template
print("1. Testing /upload/template...")
try:
    response = requests.post(
        'http://localhost:8000/upload/template',
        files={'file': ('test.docx', test_file, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')}
    )
    print(f"   Status: {response.status_code}")
    print(f"   Response: {response.text[:200]}")
except Exception as e:
    print(f"   Error: {e}")

print()

# Test /upload/image
test_file2 = io.BytesIO(test_content)
print("2. Testing /upload/image...")
try:
    response = requests.post(
        'http://localhost:8000/upload/image',
        files={'file': ('test.jpg', test_file2, 'image/jpeg')}
    )
    print(f"   Status: {response.status_code}")
    print(f"   Response: {response.text[:200]}")
except Exception as e:
    print(f"   Error: {e}")