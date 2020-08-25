FROM alpine:3.7
RUN apk --update add bash postgresql-client
RUN apk --no-cache add curl
WORKDIR /app
ADD ./bash-cli/base.sh .
ADD ./entrypoint.sh .
ADD ./provision.sh .

RUN chmod +x *.sh

ENTRYPOINT ["/app/entrypoint.sh"]
