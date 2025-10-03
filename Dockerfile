FROM nixos/nix
COPY shell.nix .
ENV IS_CI=true
RUN nix-shell shell.nix --run "echo Environment ready"

CMD ["bash"]