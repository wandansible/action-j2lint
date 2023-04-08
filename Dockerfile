FROM python:3.10-slim

COPY requirements.txt /requirements.txt
COPY entrypoint.sh /entrypoint.sh

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      git \
      jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/pip --no-cache-dir --no-input install --upgrade --requirement /requirements.txt

ENTRYPOINT ["/entrypoint.sh"]
