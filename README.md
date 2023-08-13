# Oubliette eBuild version bumper

Ahelper scripts for automatically version bumping Gentoo ebuild packages within the [oubliette-overlay](https://github.com/nabbi/oubliette-overlay)


## Docker

[docker pull nabbi/oubliette-ebuild-verbump:latest](https://hub.docker.com/repository/docker/nabbi/oubliette-ebuild-verbump/general)

```shell
docker buildx build . -t nabbi/oubliette-ebuild-verbump
```

```shell
docker run --init  \
    -v ./local/ssh:/root/.ssh:ro \
    -v ./local/gitconfig:/root/.gitconfig:ro \
    -it nabbi/oubliette-ebuild-verbump bash
```
