ARG CERTBOT_TAG=latest

FROM certbot/certbot:${CERTBOT_TAG}

RUN pip install --no-cache-dir certbot-dns-hetzner-cloud

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
