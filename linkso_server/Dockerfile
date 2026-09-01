FROM rust:1.98.0-bookworm@sha256:82150a52ec202c1b14d7817e14516c392bb7f5cfebd88f1ed531cb37ebd39922 AS builder

WORKDIR /build
COPY linkso_server/Cargo.toml linkso_server/Cargo.lock ./
COPY linkso_server/migrations ./migrations
COPY linkso_server/src ./src
ARG CARGO_BUILD_JOBS
RUN cargo build --locked --release

FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171 AS runtime

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates wget \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 linkso \
    && useradd --uid 10001 --gid linkso --no-create-home --shell /usr/sbin/nologin linkso

COPY --from=builder /build/target/release/linkso_server /usr/local/bin/linkso_server

USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/linkso_server"]
CMD ["serve"]
