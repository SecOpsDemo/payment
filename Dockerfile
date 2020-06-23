# Dockerfile

FROM golang:1.7

RUN mkdir /app
COPY /target/main /app/main

CMD ["/app/main", "-port=80"]
