FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies for psycopg2 and reportlab/docusign if needed
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       gcc \
       libpq-dev \
       libffi-dev \
       libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Optional: install extra DocuSign requirements if present
COPY requirements_docusign.txt ./
RUN if [ -f requirements_docusign.txt ]; then pip install --no-cache-dir -r requirements_docusign.txt; fi

COPY . .

CMD ["gunicorn", "-c", "gunicorn_conf.py", "app:app"]
