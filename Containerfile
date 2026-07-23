FROM alpine:latest

RUN apk add --no-cache bash curl

COPY ./run.sh .

RUN chmod 0755 ./run.sh

HEALTHCHECK --interval=1m --timeout=3s \
  CMD pidof bash || exit 1

ENTRYPOINT ["./run.sh"]
