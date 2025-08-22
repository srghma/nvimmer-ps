# nix-shell:
# 	pkgs.lua5_1 pkgs.luarocks

nix-shell:
	nix shell "github:nvim-neorocks/neorocks"

runtests:
	luarocks test
	busted

docker:
	docker build -t mytestluaproject .
	# docker run -it -v "$$(pwd):/data" --entrypoint "" mytestluaproject /bin/sh
	docker run -it -v "$$(pwd):/data" mytestluaproject bash

# apk add lua5.1
# luarocks test
# busted
