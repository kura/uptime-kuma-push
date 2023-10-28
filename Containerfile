FROM alpine:latest

RUN apk add python3

COPY ./run.py .

HEALTHCHECK --interval=1m --timeout=3s \
  CMD pidof python3 || exit 1

CMD ["./run.py"]
