FROM alpine:3.15 as unbound
LABEL maintainer="Eelco Wesemann <dockerhub@init1.nl>"

ENV NAME=unbound \
    UNBOUND_VERSION=1.16.0 \
    UNBOUND_SHA256=6701534c938eb019626601191edc6d012fc534c09d2418d5b92827db0cbe48a5 \
    UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-1.16.0.tar.gz

WORKDIR /tmp/src

RUN apk --update add bash curl ldns-tools libevent expat g++ make \
                     libevent-dev expat-dev nghttp2-dev protobuf-c-dev \
                     protobuf-c-compiler openssl-dev hiredis-dev && \
    curl -sSL $UNBOUND_DOWNLOAD_URL -o unbound.tar.gz && \
    echo "${UNBOUND_SHA256} *unbound.tar.gz" | sha256sum -c - && \
    tar xzf unbound.tar.gz && \
    rm -f unbound.tar.gz && \
    cd unbound-1.16.0 && \
    addgroup -S _unbound && \
    adduser -S _unbound -G _unbound && \
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
    make install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    rm -rf \
        /opt/unbound/share/man \
        /tmp/* \
        /var/tmp/*


FROM alpine:3.15
LABEL maintainer="Eelco Wesemann <dockerhub@init1.nl>"

ENV NAME=unbound \
    UNBOUND_VERSION=1.16.0 \
    SUMMARY="${NAME} is a validating, recursive, and caching DNS resolver." \
    DESCRIPTION="${NAME} is a validating, recursive, and caching DNS resolver."

WORKDIR /tmp/src

COPY --from=unbound /opt /opt

RUN apk --update add ca-certificates ldns-tools libevent nghttp2-libs expat \
                     hiredis protobuf-c bash perl drill && \
    addgroup -S _unbound && \
    adduser -S _unbound -G _unbound && \
    rm -rf \
        /opt/unbound/share/man \
        /tmp/* \
        /var/tmp/*

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
