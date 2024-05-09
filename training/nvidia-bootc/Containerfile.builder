FROM quay.io/centos/centos:stream9

ARG KERNEL_VERSION=''
ARG ENABLE_RT=''

USER root

RUN if [ "${KERNEL_VERSION}" == "" ]; then \
        NEWER_KERNEL_CORE=$(dnf info kernel-core | awk -F: '/^Source/{gsub(/.src.rpm/, "", $2); print $2}' | sort -n | tail -n1) \
        && RELEASE=$(dnf info ${NEWER_KERNEL_CORE} | awk -F: '/^Release/{print $2}' | tr -d '[:blank:]') \
        && VERSION=$(dnf info ${NEWER_KERNEL_CORE} | awk -F: '/^Version/{print $2}' | tr -d '[:blank:]') \
        && export KERNEL_VERSION="${VERSION}-${RELEASE}" ;\
        fi \
    && echo "${KERNEL_VERSION}" \
    && dnf -y install dnf-plugin-config-manager \
    && dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save \
    && dnf -y install \
        kernel-devel-${KERNEL_VERSION} \
        kernel-modules-${KERNEL_VERSION} \
        kernel-modules-extra-${KERNEL_VERSION} \
    && if [ "${ENABLE_RT}" ] && [ $(arch) == "x86_64" ]; then \
        dnf -y --enablerepo=rt install \
            kernel-rt-devel-${KERNEL_VERSION} \
            kernel-rt-modules-${KERNEL_VERSION} \
            kernel-rt-modules-extra-${KERNEL_VERSION}; \
    fi \
    && export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-core-${KERNEL_VERSION}) \
    && export GCC_VERSION=$(cat /lib/modules/${INSTALLED_KERNEL}/config | grep -Eo "gcc \(GCC\) ([0-9\.]+)" | grep -Eo "([0-9\.]+)") \
    && dnf -y install \
        binutils \
        diffutils \
        elfutils-libelf-devel \
        jq \
        kabi-dw kernel-abi-stablelists \
        keyutils \
        kmod \
        gcc-${GCC_VERSION} \
        git \
        make \
        mokutil \
        openssl \
        pinentry \
        rpm-build \
        xz \
    && dnf clean all \
    && useradd -u 1001 -m -s /bin/bash builder

# Last layer for metadata for mapping the driver-toolkit to a specific kernel version
RUN if [ "${KERNEL_VERSION}" == "" ]; then \
        export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-core); \
    else \
        export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel-core-${KERNEL_VERSION}) ;\
    fi \
    && echo "{ \"KERNEL_VERSION\": \"${INSTALLED_KERNEL}\" }" > /etc/driver-toolkit-release.json \
    && echo -e "KERNEL_VERSION=\"${INSTALLED_KERNEL}\"" > /etc/driver-toolkit-release.sh

USER builder
