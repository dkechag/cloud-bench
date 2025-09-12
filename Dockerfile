FROM debian:trixie

RUN apt-get update && apt-get install -y wget build-essential cpanminus \
    libxml-simple-perl libjpeg-dev libexpat1-dev zlib1g-dev libssl-dev libdb-dev \
    libjpeg-dev php-cli php-xml php-zip autoconf p7zip-full mesa-utils vulkan-tools \
    unzip apt-file curl

RUN cpanm -n Benchmark::DKbench
RUN setup_dkbench --force

RUN wget https://phoronix-test-suite.com/releases/phoronix-test-suite-10.8.4.tar.gz && \
    tar xvfz phoronix-test-suite-10.8.4.tar.gz && \
    cd phoronix-test-suite && \
    ./install-sh

# Preconfigure batch mode for unattended runs
RUN printf "Y\nN\nN\nN\nN\nN\nN\n" | phoronix-test-suite batch-setup
RUN phoronix-test-suite install openssl
RUN phoronix-test-suite install compress-7zip

RUN bash -c ' \
  set -e && \
  curl -L https://install.perlbrew.pl | bash && \
  source ~/perl5/perlbrew/etc/bashrc && \
  perlbrew download perl-5.36.0 \
'

RUN set -e && \
    cd /root && \
    ARCH=$(uname -m) && \
    [ "$ARCH" = "x86_64" ] && ARCH=amd64 || true && \
    [ "$ARCH" = "aarch64" ] && ARCH=arm64 || true && \
    wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-$ARCH-static.tar.xz && \
    tar -xJf ffmpeg-release-$ARCH-static.tar.xz --wildcards --no-anchored 'ffmpeg' -O > /usr/bin/ffmpeg && \
    rm ffmpeg-release-$ARCH-static.tar.xz && \
    chmod +x /usr/bin/ffmpeg && \
    if [ "$ARCH" = "arm64" ]; then \
        wget https://cdn.geekbench.com/Geekbench-5.4.0-LinuxARMPreview.tar.gz && \
        tar xvfz Geekbench-5.4.0-LinuxARMPreview.tar.gz && \
        rm Geekbench-5.4.0-LinuxARMPreview.tar.gz; \
    else \
        wget https://cdn.geekbench.com/Geekbench-5.4.4-Linux.tar.gz && \
        tar xvfz Geekbench-5.4.4-Linux.tar.gz && \
        rm Geekbench-5.4.4-Linux.tar.gz; \
    fi

RUN cd /root && wget https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_720p_h264.mov

COPY bench.pl /root/bench.pl

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
