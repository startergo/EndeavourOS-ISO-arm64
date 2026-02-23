# EndeavourOS aarch64 ISO Build Environment
# Based on Arch Linux ARM with build dependencies
FROM menci/archlinuxarm:base-devel

LABEL maintainer="startergo <startergo@protonmail.com>"
LABEL description="Build environment for EndeavourOS aarch64 ISO"

# Initialize pacman keyring and populate
RUN pacman-key --init && \
    pacman-key --populate archlinuxarm

# Copy configuration files
COPY pacman.conf /etc/pacman.conf
COPY docker-entrypoint.sh /usr/local/bin/

# Set up Entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Set up EndeavourOS ARM repo
RUN mkdir -p /etc/pacman.d && \
    printf 'Server = https://mirror.alpix.eu/endeavouros/repo/$repo/$arch\n' \
        > /etc/pacman.d/endeavouros-mirrorlist

    # Upgrade pacman's runtime deps atomically to avoid ABI mismatches in subsequent RUN steps
RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm --needed --overwrite '*' \
        libgcc libgomp libstdc++ \
        openssl libssh2 curl libarchive \
        zlib bzip2 xz zstd && \
    pacman -S --noconfirm --needed \
        imagemagick \
        ttf-dejavu \
        squashfs-tools \
        dosfstools \
        mtools \
        xorriso \
        zstd \
        arch-install-scripts \
        curl \
        wget \
        git \
        make

# Verify required binaries are present (fails the build if any are missing)
RUN command -v magick && \
    command -v wget && \
    command -v mksquashfs && \
    command -v mkfs.fat && \
    command -v mmd && \
    command -v mcopy

# Install EndeavourOS keyring: receive + lsign key first so pacman can verify the package
RUN pacman-key --recv-keys A367FB01AE54040E --keyserver hkps://keyserver.ubuntu.com && \
    pacman-key --lsign-key A367FB01AE54040E && \
    pacman -S --noconfirm --needed endeavouros-keyring && \
    pacman-key --populate endeavouros

# Install archiso from source
RUN git clone --depth 1 https://gitlab.archlinux.org/archlinux/archiso.git /tmp/archiso && \
    make -C /tmp/archiso install-scripts install-profiles install-doc && \
    rm -rf /tmp/archiso && \
    { gpgconf --kill gpg-agent || true; }

# Set working directory
WORKDIR /workspace

# Default command: run prepare.sh then build
CMD ["bash", "-c", "bash prepare.sh && bash mkarchiso -v ."]
