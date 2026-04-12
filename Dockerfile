# Production image: static build + unprivileged nginx (suitable for Kubernetes).
FROM alpine:3.20 AS hugo
ARG HUGO_VERSION=0.160.1
RUN apk add --no-cache curl tar \
  && curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin hugo

WORKDIR /src
COPY . .
RUN hugo --minify --environment production

FROM lipanski/docker-static-website:2.6.0
COPY --from=hugo /src/public /home/static