# Production image: static build + unprivileged nginx (suitable for Kubernetes).
FROM alpine:3.20 AS hugo
ARG HUGO_VERSION=0.160.1
RUN apk add --no-cache curl tar \
  && curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin hugo

WORKDIR /src
COPY . .
RUN hugo --minify --environment production

FROM nginxinc/nginx-unprivileged:1.26-alpine
COPY --from=hugo /src/public /usr/share/nginx/html
COPY deploy/nginx-default.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
