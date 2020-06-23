# Dockerfile

FROM alpine:3.4

RUN mkdir /app
COPY /target/main /app/main

CMD ["/app/main", "-port=80"]
