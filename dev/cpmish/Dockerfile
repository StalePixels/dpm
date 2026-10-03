FROM ubuntu:24.04

ARG ACK_COMMIT=7afa32a0a0f13e865fa2e8104e442689005cd627

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential ca-certificates git python3 ninja-build \
        cpmtools flex bison libreadline-dev libz80ex-dev lua5.2 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/davidgiven/ack.git /tmp/ack \
    && git -C /tmp/ack checkout $ACK_COMMIT \
    && sed -i 's/PLATS = all/PLATS = cpm/' /tmp/ack/Makefile \
    && make -C /tmp/ack PREFIX=/usr/local install \
    && rm -rf /tmp/ack

WORKDIR /src
