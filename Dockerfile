FROM python:3.10-slim

RUN apt-get update && \
    apt-get install -y \
      git \
      jq

COPY requirements.txt /requirements.txt

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade --requirement requirements.txt

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
