FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171 AS builder

ARG FLUTTER_VERSION=3.47.2
ARG FLUTTER_ARCHIVE_SHA256=447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl git xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && curl --fail --show-error --location \
      --output /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && echo "${FLUTTER_ARCHIVE_SHA256}  /tmp/flutter.tar.xz" | sha256sum --check --strict \
    && tar --extract --xz --file /tmp/flutter.tar.xz --directory /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter config --no-analytics \
    && flutter precache --web

ARG API_BASE_URL=http://localhost:8088
WORKDIR /build
COPY linkso_client/pubspec.yaml linkso_client/pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY linkso_client .
RUN flutter build web --release --wasm --no-web-resources-cdn --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.31.4-alpine@sha256:db35bfc6b2951e7f8a72db5db120288c127ffaeeb4a6d4b95a26fead017d5913 AS runtime

COPY deploy/nginx/security_headers.conf /etc/nginx/snippets/linkso-security.conf
COPY deploy/nginx/production_security_headers.conf /etc/nginx/snippets/linkso-production-security.conf
COPY deploy/nginx/local.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /build/build/web /usr/share/nginx/html

EXPOSE 8080
