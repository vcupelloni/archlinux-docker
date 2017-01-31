FROM scratch
MAINTAINER Valerio Cupelloni <valerio.cupelloni@myefm.it>

# Set the $architecture ARG on your `docker build' command line with `--build-arg architecture=x86_64' or `i686'.
ARG architecture

ADD bootstrap.tar.gz /

RUN if [ "$architecture" != "x86_64" -a "$architecture" != "i686" ]; then \
    printf '\nYou need to specify the architecture with "--build-arg architecture=i686" on your\n\
    \r"docker build" command line. "x86_64" and "i686" are supported. Aborting build!\n\n'; exit 1; fi

RUN ln -s /usr/share/zoneinfo/UTC /etc/localtime \
    && pacman-key --init \
    && pacman-key --populate archlinux \
    # Unfortunately this hack has to stay until Arch Linux bootstrap tarballs start including `sed' package, which is
    # required by `rankmirrors', which comes with `pacman' package, while that one doesn't depend on `sed'. (Note to
    # self: ask the Arch devs about this; `locale-gen' uses `sed' too).
    && pacman -U --noconfirm --noprogressbar --arch $architecture https://www.archlinux.org/packages/core/${architecture}/sed/download/ \
    && sed -i "s/^Architecture = auto$/Architecture = $architecture/" /etc/pacman.conf \
    && sed -n 's/^#Server = https/Server = https/p' /etc/pacman.d/mirrorlist > /tmp/mirrorlist \
    && rankmirrors -n 3 /tmp/mirrorlist | tee /etc/pacman.d/mirrorlist \
    && rm /tmp/mirrorlist \
    # `locale-gen' needs `gzip' (via `localedef', which works on /usr/share/i18n/charmaps/*.gz), `paccache' needs `awk'.
    && pacman -Syu --noconfirm --noprogressbar --quiet procps sudo which vim tar grep sed awk wget openssh git gzip nano unzip jdk7-openjdk\
    && paccache -r -k0 \
    && echo 'it_IT.UTF-8 UTF-8' > /etc/locale.gen \
    && locale-gen \
    && echo 'LANG=it_IT.UTF-8' > /etc/locale.conf

ENV JAVA_HOME /usr/lib/jvm/default
ENV LANG it_IT.UTF-8
ENV EDITOR='vim'

RUN useradd -mU -s /bin/bash docker && echo 'docker:docker' | chpasswd
RUN echo "docker ALL=(ALL:ALL) ALL" | (EDITOR="tee -a" visudo)
RUN echo "AllowUsers docker" >> /etc/ssh/sshd_config
RUN ssh-keygen -A

# As per https://docs.docker.com/engine/userguide/networking/default_network/configure-dns/, the /etc/hostname,
# /etc/hosts and /etc/resolv.conf should be rather left alone.
