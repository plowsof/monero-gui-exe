# syntax=docker/dockerfile:1
FROM ubuntu:20.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive TZ=BST apt-get -y install tzdata git jq curl wget unzip

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        ca-certificates \
        language-pack-en \
        language-pack-zh-han* \
        locales \
        locales-all \
        wget

# Install Wine
RUN dpkg --add-architecture i386 && \
    wget -nc https://dl.winehq.org/wine-builds/winehq.key && \
    mv winehq.key /usr/share/keyrings/winehq-archive.key && \
    wget -nc https://dl.winehq.org/wine-builds/ubuntu/dists/focal/winehq-focal.sources && \
    mv winehq-focal.sources /etc/apt/sources.list.d/ && \
    apt-get update -y && \
    # Wine 7.0 stable has some issues with some games I tested
    # Use Wine 7.11 staging instead
    apt-get install -y --install-recommends winehq-staging

COPY . ./app

WORKDIR /app

ENTRYPOINT ["./make_exe.sh"]
