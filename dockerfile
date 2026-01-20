#FROM ubuntu:22.04
FROM teriyakigod/steamcmd:arm64
# IMPORTANT: These values are set at build time and CANNOT be changed at runtime
# The container has fixed user IDs:
# - 2_0_latest image: PUID=1000, PGID=1000
# - 2_1_latest image: PUID=7777, PGID=7777
# Host file ownership MUST match these values to avoid permission issues
ARG PUID=7777
ARG PGID=7777

# Set a default timezone, can be overridden at runtime
ENV TZ=UTC
ENV PUID=${PUID}
ENV PGID=${PGID}
ENV PROTON_USE_ESYNC=1 
ENV DEBIAN_FRONTEND=noninteractive
# Set specific Wine version to ensure consistency
ENV WINEDLLOVERRIDES="version=n,b;vcrun2022=n,b"
ENV WINEPREFIX="/home/pok/.steam/steam/steamapps/compatdata/2430930/pfx"
ENV DISPLAY=:0.0

USER root

# Install necessary packages and setup for WineHQ repository
RUN set -ex; \
    #dpkg --add-architecture i386; \
    dpkg --add-architecture armhf; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    jq curl wget tar unzip nano gzip iproute2 procps dbus \
    tzdata \
    # tzdata package provides timezone database for TZ environment variable support \
    lib32gcc-s1-amd64-cross libglib2.0-0 libglib2.0-0:armhf libvulkan1 libvulkan1:armhf \
    libnss3 libnss3:armhf libgconf-2-4 libgconf-2-4:armhf \
    libfontconfig1 libfontconfig1:armhf libfreetype6 libfreetype6:armhf \
    libcups2 libcups2:armhf \
    gnupg2 ca-certificates \
    # Add X server packages for headless operation
    xvfb x11-xserver-utils xauth libgl1-mesa-dri libgl1-mesa-glx \
    # Add necessary libraries for Wine and VC++
    libldap-2.5-0:armhf libldap-2.5-0 libgnutls30:armhf libgnutls30 \
    libxml2:armhf libxml2 libasound2:armhf libasound2 libpulse0:armhf libpulse0 \
    libopenal1:armhf libopenal1 libncurses6:armhf libncurses6 \
    # DO NOT ENABLE screen package - causes log display issues which is needed by the POK-manager.sh script
    # cabextract is essential for winetricks vcrun2019 installation
    cabextract winbind software-properties-common; \
    # Setup WineHQ repository
    mkdir -pm755 /etc/apt/keyrings; \
    #wget -O - https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key; \
    #wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources; \
    apt-get update; \
    # Install latest stable Wine
    #apt-get install -y --install-recommends winehq-stable; \
    apt-get install -y --install-recommends wine-stable;
    # Cleanup to keep the image lean

# Install dependencies for fex-emu
#RUN apt-get install -y \
#    git cmake ninja-build ccache pkg-config clang llvm lld binfmt-support libsdl2-dev libepoxy-dev libssl-dev python-setuptools g++-x86-64-linux-gnu \
#    nasm python3-clang libstdc++-10-dev-i386-cross libstdc++-10-dev-amd64-cross libstdc++-10-dev-arm64-cross squashfs-tools squashfuse libc-bin expect curl sudo fuse


RUN set -ex; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*
# Setup winetricks for Visual C++ Redistributable installation
RUN set -ex; \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/local/bin/winetricks && \
    chmod +x /usr/local/bin/winetricks

# Create the pok group and user, assign home directory, and add to the 'users' group  
RUN set -ex; \
    groupadd -g ${PGID} pok && \
    useradd -d /home/pok -u ${PUID} -g pok -G users -m pok; \
    mkdir -p /home/pok/arkserver /home/pok/.steam/steam/compatibilitytools.d; \
    # Create critical directories for ASA API
    mkdir -p /home/pok/arkserver/ShooterGame/Binaries/Win64/logs; \
    mkdir -p /home/pok/arkserver/ShooterGame/Saved/Config/WindowsServer; \
    mkdir -p /home/pok/arkserver/ShooterGame/Saved/SavedArks; \
    mkdir -p /home/pok/arkserver/ShooterGame/Saved/Logs

# Create a new user for fex-emu and set their home directory
#RUN useradd -m -s /bin/bash fex

#RUN usermod -aG sudo fex

#RUN echo "fex ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/fex

#USER fex

#WORKDIR /home/fex

#Clone the FEX repository and build it
#RUN git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git && \
#    cd FEX && \
#    mkdir Build && \
#    cd Build && \
#    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DUSE_LINKER=lld -DENABLE_LTO=True -DBUILD_TESTS=False -DENABLE_ASSERTIONS=False -G Ninja .. && \
#    ninja

#WORKDIR /home/fex/FEX/Build

#RUN sudo ninja install && \
#    sudo ninja binfmt_misc_32 && \
#    sudo ninja binfmt_misc_64

#RUN sudo useradd -m -s /bin/bash steam

#RUN sudo apt install wget

#USER root

#RUN echo 'root:steamcmd' | chpasswd

#USER steam

#WORKDIR /home/steam/.fex-emu/RootFS/

# Set up rootfs

#RUN wget -O Ubuntu_22_04.tar.gz https://www.dropbox.com/scl/fi/16mhn3jrwvzapdw50gt20/Ubuntu_22_04.tar.gz?rlkey=4m256iahwtcijkpzcv8abn7nf

#RUN tar xzf Ubuntu_22_04.tar.gz

#RUN rm ./Ubuntu_22_04.tar.gz

#WORKDIR /home/steam/.fex-emu

#RUN echo '{"Config":{"RootFS":"Ubuntu_22_04"}}' > ./Config.json

#WORKDIR /home/steam/Steam

# Download and run SteamCMD
#RUN curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Setup the Proton GE with proper version handling
WORKDIR /usr/local/bin
RUN set -ex; \
    curl -sLOJ "$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep browser_download_url | cut -d\" -f4 | grep .tar.gz)"; \
    # Extract the version from filename
    PROTON_VERSION=$(ls GE-Proton*.tar.gz | sed 's/\.tar\.gz//'); \
    # Extract to temp directory
    mkdir -p /tmp/proton-extract; \
    tar -xzf GE-Proton*.tar.gz -C /tmp/proton-extract; \
    # Create official proton directories
    mkdir -p /home/pok/.steam/steam/compatibilitytools.d; \
    # Move to final location
    mv /tmp/proton-extract/* /home/pok/.steam/steam/compatibilitytools.d/; \
    # Create a known path for compatibility
    ln -sf /home/pok/.steam/steam/compatibilitytools.d/$PROTON_VERSION /home/pok/.steam/steam/compatibilitytools.d/GE-Proton-Current; \
    # Also create compatibility symlinks for both common version numbers
    ln -sf /home/pok/.steam/steam/compatibilitytools.d/$PROTON_VERSION /home/pok/.steam/steam/compatibilitytools.d/GE-Proton8-21; \
    ln -sf /home/pok/.steam/steam/compatibilitytools.d/$PROTON_VERSION /home/pok/.steam/steam/compatibilitytools.d/GE-Proton9-25; \
    # Cleanup
    rm -rf /tmp/proton-extract GE-Proton*.*

# Setup machine-id for Proton
RUN set -ex; \
    rm -f /etc/machine-id; \
    dbus-uuidgen --ensure=/etc/machine-id; \
    rm -f /var/lib/dbus/machine-id; \
    dbus-uuidgen --ensure

WORKDIR /tmp/
# Setup rcon-cli
RUN set -ex; \
    wget -qO- https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz | tar xvz && \
    mv rcon-0.10.3-amd64_linux/rcon /usr/local/bin/rcon-cli && \
    chmod +x /usr/local/bin/rcon-cli

# Install tini
ARG TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# Setup and pre-initialize Wine environment for AsaApi
RUN set -ex; \
    # Create a complete Wine prefix structure
    mkdir -p /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/windows/system32; \
    mkdir -p /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/Program\ Files/Common\ Files; \
    mkdir -p /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/Program\ Files\ \(x86\)/Common\ Files; \
    mkdir -p /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/users/steamuser/Temp; \
    mkdir -p /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/dosdevices; \
    # Create proper symlinks for dosdevices
    ln -sf "../drive_c" /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/dosdevices/c:; \
    ln -sf "/dev/null" /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/dosdevices/d::; \
    ln -sf "/dev/null" /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/dosdevices/e::; \
    ln -sf "/dev/null" /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/dosdevices/f::; \
    # Create comprehensive Visual C++ structure for AsaApi (aligned with VS 2022 redistributables)
    mkdir -p /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2022/BuildTools/VC/Redist/MSVC/14.44.35211/x64/Microsoft.VC143.CRT; \
    mkdir -p /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2022/BuildTools/VC/Redist/MSVC/14.44.35211/x86/Microsoft.VC143.CRT; \
    mkdir -p /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/windows/system32/vcruntime; \
    # Create VC++ dummy files so ASA API loaders detect the redistributable during first boot
    touch /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2022/BuildTools/VC/Redist/MSVC/14.44.35211/x64/Microsoft.VC143.CRT/msvcp140.dll; \
    touch /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2022/BuildTools/VC/Redist/MSVC/14.44.35211/x64/Microsoft.VC143.CRT/vcruntime140.dll; \
    touch /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2022/BuildTools/VC/Redist/MSVC/14.44.35211/x86/Microsoft.VC143.CRT/msvcp140.dll; \
    touch /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/drive_c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/2022/BuildTools/VC/Redist/MSVC/14.44.35211/x86/Microsoft.VC143.CRT/vcruntime140.dll; \
    # Create wine registry files with proper configuration
    echo "WINE REGISTRY Version 2" > /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/system.reg; \
    echo ";; All keys relative to \\\\Machine" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/system.reg; \
    echo "#arch=win64" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/system.reg; \
    echo "" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/system.reg; \
    echo "WINE REGISTRY Version 2" > /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/user.reg; \
    echo ";; All keys relative to \\\\User\\\\S-1-5-21-0-0-0-1000" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/user.reg; \
    echo "#arch=win64" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/user.reg; \
    echo "[Software\\\\Wine\\\\DllOverrides]" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/user.reg; \
    echo "\"*version\"=\"native,builtin\"" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/user.reg; \
    echo "\"vcrun2019\"=\"native,builtin\"" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/user.reg; \
    echo "" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/user.reg; \
    echo "WINE REGISTRY Version 2" > /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/userdef.reg; \
    echo ";; All keys relative to \\\\User\\\\DefUser" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/userdef.reg; \
    echo "#arch=win64" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/userdef.reg; \
    echo "" >> /home/pok/.steam/steam/steamapps/compatdata/2430930/pfx/userdef.reg; \
    # Create tracked_files to mark prefix as initialized
    touch /home/pok/.steam/steam/steamapps/compatdata/2430930/tracked_files

# Set proper permissions for everything
RUN set -ex; \
    # Set proper permissions for user pok
    chown -R pok:pok /home/pok; \
    chown -R pok:pok /home/pok/arkserver; \
    chown -R pok:pok /home/pok/.steam; \
    chown -R pok:pok /opt/steamcmd; \
    # Ensure all critical directories have proper permissions
    find /home/pok/arkserver -type d -exec chmod 755 {} \;; \
    # Make logs directory world-writable to avoid permission issues
    chmod -R 777 /home/pok/arkserver/ShooterGame/Binaries/Win64/logs; \
    chmod -R 777 /home/pok/arkserver/ShooterGame/Saved/Logs; \
    # Ensure Wine prefix has correct permissions
    chown -R pok:pok /home/pok/.steam/steam/steamapps/compatdata/2430930; \
    chmod -R 755 /home/pok/.steam/steam/steamapps/compatdata/2430930; \
    # Make AsaApi directories executable
    mkdir -p /home/pok/arkserver/ShooterGame/Binaries/Win64/AsaApi; \
    chmod -R 755 /home/pok/arkserver/ShooterGame/Binaries/Win64/AsaApi; \
    chmod -R +x /home/pok/arkserver/ShooterGame/Binaries/Win64; \
    # Ensure winetricks can run for user pok
    chmod +x /usr/local/bin/winetricks

# Download and pre-install VC++ Redistributable (14.44.35211.0)
USER pok
RUN set -ex; \
    mkdir -p /tmp/vcredist; \
    cd /tmp/vcredist; \
    wget -q https://aka.ms/vs/17/release/vc_redist.x64.exe; \
    wget -q https://aka.ms/vs/17/release/vc_redist.x86.exe; \
    # Prefer vcrun2022 for latest VC++ runtime; fall back to vcrun2019 if winetricks lacks the verb
    WINEPREFIX="/home/pok/.steam/steam/steamapps/compatdata/2430930/pfx" \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    winetricks -q vcrun2022 || winetricks -q vcrun2019 || true; \
    # Install the official redistributables quietly for both architectures
    WINEPREFIX="/home/pok/.steam/steam/steamapps/compatdata/2430930/pfx" \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    wine64 /tmp/vcredist/vc_redist.x64.exe /quiet /norestart || true; \
    WINEPREFIX="/home/pok/.steam/steam/steamapps/compatdata/2430930/pfx" \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    wine /tmp/vcredist/vc_redist.x86.exe /quiet /norestart || true; \
    rm -rf /tmp/vcredist

USER root
# Copy scripts and defaults folders into the container, ensure they are executable
COPY --chown=pok:pok scripts/ /home/pok/scripts/
COPY --chown=pok:pok defaults/ /home/pok/defaults/
RUN chmod +x /home/pok/scripts/*.sh

# Create essential runtime directories with proper permissions
RUN set -ex; \
    mkdir -p /home/pok/logs; \
    chown -R pok:pok /home/pok/logs; \
    chmod -R 755 /home/pok/logs; \
    # Create convenience symlinks for monitoring logs
    ln -sf "/home/pok/arkserver/ShooterGame/Saved/Logs/ShooterGame.log" "/home/pok/shooter_game.log" 2>/dev/null || true; \
    # Setup X11 directories 
    mkdir -p /tmp/.X11-unix; \
    chmod 1777 /tmp/.X11-unix; \
    # Prepare for Xvfb in container
    touch /tmp/.X0-lock; \
    chmod 1777 /tmp/.X0-lock; \
    chown pok:pok /tmp/.X0-lock; \
    # Final permission check
    chown -R pok:pok /home/pok; \
    chown -R pok:pok /home/pok/arkserver/ShooterGame/Binaries/Win64/logs; \
    chmod -R 777 /home/pok/arkserver/ShooterGame/Binaries/Win64/logs

# Switch back to pok to run the entrypoint script
USER pok
WORKDIR /home/pok

# Use tini as the entrypoint  
ENTRYPOINT ["/tini", "--", "/home/pok/scripts/init.sh"]
