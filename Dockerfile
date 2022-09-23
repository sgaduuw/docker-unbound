# syntax=docker/dockerfile:1
FROM debian:stable as unbound
LABEL maintainer="Eelco Wesemann <dockerhub@init1.nl>"

ENV NAME=unbound \
    UNBOUND_VERSION=1.16.3 \
    UNBOUND_SHA256=ea0c6665e2c3325b769eac1dfccd60fe1828d5fcf662650039eccb3f67edb28e

WORKDIR /tmp/src

RUN build_deps="curl file gcc libc-dev libevent-dev libexpat1-dev libnghttp2-dev libhiredis-dev make" && \
    set -x && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      $build_deps \
      bsdmainutils \
      ca-certificates \
      ldnsutils \
      libevent-2.1-7 \
      libexpat1 \
      libprotobuf-c-dev \
      libssl-dev \
      protobuf-c-compiler && \
    curl -sSL https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz -o unbound.tar.gz && \
    echo "${UNBOUND_SHA256} *unbound.tar.gz" | sha256sum -c - && \
    tar xzf unbound.tar.gz && \
    rm -f unbound.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    ./configure \
        --disable-dependency-tracking \
        --prefix=/opt/unbound \
        --with-pthreads \
        --with-username=_unbound \
        --with-libevent \
        --with-libnghttp2 \
        --enable-dnstap \
        --enable-tfo-server \
        --enable-tfo-client \
        --enable-event-api \
        --enable-cachedb \
        --with-libhiredis \
        --enable-subnet && \
    make -j $(getconf _NPROCESSORS_ONLN) all && \
    make install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    apt-get purge -y --auto-remove \
      $build_deps && \
    rm -rf \
        /opt/unbound/share/man \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

# syntax=docker/dockerfile:1
FROM debian:stable
LABEL maintainer="Eelco Wesemann <dockerhub@init1.nl>"

ENV NAME=unbound \
    VERSION=1.16.3 \
    SUMMARY="Unbound is a validating, recursive, and caching DNS resolver." \
    DESCRIPTION="Unbound is a validating, recursive, and caching DNS resolver."

WORKDIR /tmp/src

COPY --from=unbound /opt /opt

RUN set -x && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      bsdmainutils \
      ca-certificates \
      ldnsutils \
      libevent-2.1-7 \
      libnghttp2-14 \
      libexpat1 \
      libhiredis0.14 \
      libprotobuf-c1 && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    apt-get purge -y --auto-remove \
      $build_deps && \
    rm -rf \
        /opt/unbound/share/man \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

COPY data/ /

RUN chmod +x /unbound.sh

WORKDIR /opt/unbound/

ENV PATH /opt/unbound/sbin:"$PATH"

LABEL org.opencontainers.image.version=${UNBOUND_VERSION} \
      org.opencontainers.image.title="sgaduuw/unbound" \
      org.opencontainers.image.description="a validating, recursive, and caching DNS resolver with CacheDB and Redis support" \
      org.opencontainers.image.url="https://hub.docker.com/r/sgaduuw/unbound" \
      org.opencontainers.image.vendor="Eelco Wesemann" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/sgaduuw/docker-unbound"

EXPOSE 53/tcp
EXPOSE 53/udp

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 CMD drill @127.0.0.1 cloudflare.com || exit 1

CMD ["/unbound.sh"]
