# Use the Luajit with Luarocks base image
FROM nickblah/luajit:2-luarocks

# RUN apt-get update && \
#     apt-get install -y git build-essential libc-dev wget fuse && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/* && \
#     wget https://github.com/neovim/neovim/releases/latest/download/nvim.appimage && \
#     chmod +x ./nvim.appimage && \
#     mv nvim.appimage /usr/local/bin/nvim

# Install necessary packages
RUN apt-get update && \
    apt-get install -y git build-essential libc-dev wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and extract Neovim AppImage
RUN wget https://github.com/neovim/neovim/releases/latest/download/nvim.appimage && \
    chmod +x ./nvim.appimage && \
    ./nvim.appimage --appimage-extract && \
    mv squashfs-root /usr/local/nvim && \
    rm nvim.appimage

WORKDIR /data

COPY *.rockspec /data/
RUN (luarocks install nlua plenary.nvim || true)
RUN (cd /data/ && luarocks test || true)
