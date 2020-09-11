FROM i386/ubuntu:bionic AS builder

WORKDIR /usr

#RUN apk add --update gcc libc6-compat

RUN apt-get update && apt-get install -y git build-essential


WORKDIR /usr/

ENV INFERNO_BRANCH=master
ENV INFERNO_COMMIT=ed97654bd7a11d480b44505c8300d06b42e5fefe
  

#ADD ./inferno-os /usr/inferno-os
#ADD patches/mk_http.patch /tmp
RUN git clone --depth 1 -b ${INFERNO_BRANCH} https://bitbucket.org/inferno-os/inferno-os 
WORKDIR /usr/inferno-os
RUN git reset --hard ${INFERNO_COMMIT}
WORKDIR /usr/inferno-os/utils/http
RUN git clone --depth 1 -b master https://github.com/mjl-/http
WORKDIR /usr/inferno-os
#RUN patch -p1 < /tmp/mk_http.patch


#ENV PATH=$PATH:/usr/inferno-os/Linux/386/bin

RUN \
  export PATH=$PATH:/usr/inferno-os/Linux/386/bin                             \
  export MKFLAGS='SYSHOST=Linux OBJTYPE=386 CONF=emu-g ROOT='/usr/inferno-os; \
  /usr/inferno-os/Linux/386/bin/mk $MKFLAGS mkdirs                            && \
  /usr/inferno-os/Linux/386/bin/mk $MKFLAGS emuinstall                        && \
  /usr/inferno-os/Linux/386/bin/mk $MKFLAGS emunuke

FROM i386/ubuntu:bionic AS inferno
ENV ROOT_DIR /usr/inferno-os

COPY --from=builder /usr/inferno-os/Linux/386/bin/emu-g /usr/bin
COPY --from=builder /usr/inferno-os/dis $ROOT_DIR/dis
COPY --from=builder /usr/inferno-os/appl $ROOT_DIR/appl
COPY --from=builder /usr/inferno-os/lib $ROOT_DIR/lib
COPY --from=builder /usr/inferno-os/module $ROOT_DIR/module
COPY --from=builder /usr/inferno-os/usr $ROOT_DIR/usr
COPY profile /usr/inferno-os/lib/sh/profile 
RUN apt-get update && \
    apt-get install -y software-properties-common --fix-missing
RUN add-apt-repository universe
RUN apt-get update
RUN apt-get install python-pip -y
RUN apt-get install curl -y
RUN curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py
RUN python2 get-pip.py
RUN apt-get install fuse -y
#Install libfuse
ARG LIBFUSE_VERSION=fuse-3.9.3

# Installs LibFUSE so we dont end up with errors
# in coreos when trying to mount rclone.
# https://github.com/libfuse/libfuse
# https://github.com/libfuse/libfuse/releases
RUN apt-get update && apt-get upgrade -y && \
    apt-get -y install \
        build-essential \
        wget \
        meson \
        pkg-config \
        libudev-dev \
        udev

RUN wget -O "fuse.tar.xz" "https://github.com/libfuse/libfuse/releases/download/${LIBFUSE_VERSION}/${LIBFUSE_VERSION}.tar.xz" && \
    tar -xf fuse.tar.xz && \
    rm -f fuse.tar.xz && mv fuse* fuse

# Installing util/fusermount3 to /usr/local/bin/fusermount3
# Installing util/mount.fuse3 to /usr/local/sbin/mount.fuse3
RUN cd fuse && \
    mkdir build && cd build && \
    meson .. && ninja install
    
RUN pip install kubefuse
RUN curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl
RUN kubectl version --client
RUN mkdir /usr/inferno-os/kubernetes
COPY commands.sh /commands.sh
ENTRYPOINT ["/bin/bash", "/commands.sh"]

