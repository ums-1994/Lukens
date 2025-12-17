# Windows Installation Guide

## SendGrid Installation ✅

SendGrid is already installed and ready to use! You can start using it immediately by setting the environment variables.

## psycopg2-binary Issue (PostgreSQL)

If you need to install `psycopg2-binary` on Windows, you have these options:

### Option 1: Install Visual C++ Build Tools (Recommended)

1. Download and install **Microsoft C++ Build Tools**:
   - Visit: https://visualstudio.microsoft.com/visual-cpp-build-tools/
   - Download "Build Tools for Visual Studio"
   - During installation, select "C++ build tools" workload
   - Install and restart your computer

2. Then run:
   ```powershell
   pip install psycopg2-binary
   ```

### Option 2: Use Pre-built Wheel (If Available)

Try installing a pre-built wheel:
```powershell
pip install --only-binary :all: psycopg2-binary
```

### Option 3: Skip for Local Development

If you're only testing SendGrid locally and your production server already has PostgreSQL configured, you can skip installing `psycopg2-binary` locally. The SendGrid functionality will work fine without it.

### Option 4: Use psycopg3 (Alternative)

For Python 3.13, you might want to try `psycopg` (version 3):
```powershell
pip install psycopg[binary]
```

Note: This requires code changes to use psycopg3 instead of psycopg2.

## Testing SendGrid

You can test SendGrid without PostgreSQL. Just set these environment variables:

```powershell
$env:SENDGRID_API_KEY="your-api-key"
$env:SENDGRID_FROM_EMAIL="your-verified-email@domain.com"
$env:SENDGRID_FROM_NAME="Khonology"
```

Then test the email configuration:
```powershell
python check_smtp_config.py
```


