FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y curl dnsutils bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY namecheap-ddns.sh /app/
COPY .env /app/.env

RUN chmod +x /app/namecheap-ddns.sh

CMD ["/app/namecheap-ddns.sh"]
