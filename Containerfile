FROM alpine:latest

RUN apk add python3

COPY ./run.py .

RUN chmod 0755 ./run.py

HEALTHCHECK --interval=1m --timeout=3s \
  CMD pidof python3 || exit 1

ENTRYPOINT ["./run.py"]
