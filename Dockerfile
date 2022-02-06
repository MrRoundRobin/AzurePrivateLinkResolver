FROM golang:alpine AS builder
WORKDIR /coredns
ARG COREDNS_BRANCH=1.8.7
RUN apk add --update \
        git \
        make \
    && git clone --depth 1 --branch v$COREDNS_BRANCH https://github.com/coredns/coredns /coredns
#Improve caching
RUN echo "" > /coredns/plugin.cfg \
    && make gen
COPY plugin.cfg /coredns
RUN make gen \
    && make

FROM ubuntu AS deb
RUN TZ=Europe/Berlin ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y \
        ca-certificates \
        curl \
        debhelper \
        dh-systemd \
        dpkg-dev \
        jq \
        lsb-release \
        make
WORKDIR /build/debian
WORKDIR /build
COPY packages/debian/* /build/debian/
RUN chmod -x debian/*
COPY --from=builder /coredns/coredns /build/
COPY Corefile /build/debian/
RUN dpkg-buildpackage -us -uc -b

FROM scratch AS artifact
COPY --from=builder /coredns/coredns /
COPY --from=deb     /coredns_*.deb     /

FROM gcr.io/distroless/static AS APLR
EXPOSE 53/tcp
EXPOSE 53/udp
EXPOSE 80/tcp
WORKDIR /coredns
COPY --from=builder /coredns/coredns /coredns/
COPY Corefile /coredns/
ENV PUBLIC_RESOLVER="1.1.1.1"
ENV ADDITIONAL_ZONES=""
ENV CACHE_TTL="3600"
ENV LOG_CLASS="all"
ENV NSID=""
ENTRYPOINT ["/coredns/coredns"]
LABEL org.opencontainers.image.authors="robin.mueller@outlook.de"
LABEL org.opencontainers.image.title=AzurePrivateLinkResolver
LABEL org.opencontainers.image.source = "https://github.com/MrRoundRobin/AzurePrivateLinkResolver"
