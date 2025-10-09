FROM nixos/nix:2.17.1

WORKDIR /app
COPY shell.nix .

ENV IS_CI=true
RUN nix-shell shell.nix --run "echo Environment ready"

CMD ["bash"]
