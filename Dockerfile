FROM nixos/nix:2.33.0

WORKDIR /app
COPY shell.nix .

ENV IS_CI=true
RUN nix-shell shell.nix --run "echo Environment ready"

CMD ["bash"]
