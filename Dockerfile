FROM golang:latest AS builder-forward
WORKDIR /coredns
ARG COREDNS_BRANCH=1.11.1
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install -y \
        git \
        make \
    && git clone --depth 1 --branch v$COREDNS_BRANCH https://github.com/coredns/coredns /coredns
#Improve caching
RUN echo "" > /coredns/plugin.cfg \
    && make gen
COPY src/forward/plugin.cfg /coredns/
RUN make gen \
    && make

FROM builder-forward AS builder-recursive
WORKDIR /coredns
ARG COREDNS_BRANCH=1.11.1
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install -y \
        gcc \
        libunbound-dev
ENV CGO_ENABLED=1
COPY src/recursive/plugin.cfg /coredns/
RUN make gen \
    && make

FROM debian:latest AS deb-forward
RUN TZ=Europe/Berlin ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y \
        ca-certificates \
        curl \
        debhelper \
        dpkg-dev \
        jq \
        lsb-release \
        make
WORKDIR /build/debian
WORKDIR /build
COPY src/forward/debian/* /build/debian/
RUN chmod -x debian/coredns.manpages
COPY --from=builder-forward /coredns/coredns /build/
COPY src/forward/Corefile /build/
RUN dpkg-buildpackage -us -uc -b

FROM deb-forward AS deb-recursive
WORKDIR /build
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y \
        libunbound8
RUN rm -r /build/debian/*
COPY src/recursive/debian/* /build/debian/
RUN chmod -x debian/coredns.manpages
COPY --from=builder-recursive /coredns/coredns /build/
COPY src/recursive/Corefile /build/
RUN dpkg-buildpackage -us -uc -b

FROM scratch AS artifacts
COPY --from=builder-forward   /coredns/coredns /coredns-forward
COPY --from=builder-recursive /coredns/coredns /coredns-recursive
COPY --from=deb-forward       /coredns_*.deb   /coredns-forward.deb
COPY --from=deb-recursive     /coredns_*.deb   /coredns-recursive.deb

FROM debian:latest AS aplr-recursive
EXPOSE 53/tcp
EXPOSE 53/udp
EXPOSE 80/tcp
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y \
        libunbound8
WORKDIR /coredns
COPY --from=builder-recursive /coredns/coredns /coredns/
COPY src/recursive/Corefile /coredns/Corefile
ENV ADDITIONAL_ZONES=""
ENV CACHE_TTL="3600"
ENV LOG_CLASS="all"
ENV NSID=""
ENV ENABLE_IPV6="yes"
ENTRYPOINT ["/coredns/coredns"]
LABEL org.opencontainers.image.authors="robin.mueller@outlook.de"
LABEL org.opencontainers.image.title=AzurePrivateLinkResolver-Recursive
LABEL org.opencontainers.image.source = "https://github.com/MrRoundRobin/AzurePrivateLinkResolver"

FROM gcr.io/distroless/static AS aplr-forward
EXPOSE 53/tcp
EXPOSE 53/udp
EXPOSE 80/tcp
WORKDIR /coredns
COPY --from=builder-forward /coredns/coredns /coredns/
COPY src/forward/Corefile /coredns/Corefile
ENV ADDITIONAL_ZONES=""
ENV CACHE_TTL="3600"
ENV LOG_CLASS="all"
ENV NSID=""
ENV PUBLIC_RESOLVER="1.1.1.1"
ENV ENABLE_IPV6="yes"
ENTRYPOINT ["/coredns/coredns"]
LABEL org.opencontainers.image.authors="robin.mueller@outlook.de"
LABEL org.opencontainers.image.title=AzurePrivateLinkResolver-Forward
LABEL org.opencontainers.image.source = "https://github.com/MrRoundRobin/AzurePrivateLinkResolver"
