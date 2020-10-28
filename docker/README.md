## Build docker images

Build the `omnia` image:

```sh
docker load < $(nix-build --no-out-link -A omnia)
```

Or build all images in expression:

```sh
nix-build --no-out-link | xargs -L1 docker load -i
```

## Start containers

```sh
docker-compose up
```
