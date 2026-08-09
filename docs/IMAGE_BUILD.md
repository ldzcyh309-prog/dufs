# Phase 6 自定义镜像构建

## 设计

`Dockerfile.custom` 保留官方 Dockerfile 的 amd64 Rust musl 多阶段构建和
scratch 运行时思路。最终镜像只包含 `/bin/dufs`、`/assets/` 和 OCI 元数据；
不会复制 runtime `.env`、config、data、logs、backup 或任何凭据。

`/assets/` 来自仓库中经过 Phase 5 验证的 `custom/assets/`。因此镜像在没有
宿主机挂载时也能提供 Custom UI V1。生产 Compose 仍会以只读
`/home/ldzcyh/dockerApps/dufs/assets:/assets:ro` 挂载覆盖该目录，并使用
`--assets /assets`；这提供了可审查的运行时覆盖与镜像内 fallback。

## 构建范围与标签

Phase 6 仅验证当前生产主机所需的 `linux/amd64`。上游版本由
`Cargo.toml` 读取；不可变风格标签使用 Custom UI 已验证提交的短 SHA：

```bash
docker build --platform linux/amd64 -f Dockerfile.custom \
  --build-arg IMAGE_VERSION=0.46.0-custom-v1-<git-short-sha> \
  --build-arg VCS_REF=<git-full-sha> \
  -t dufs:0.46.0-custom-v1-<git-short-sha> \
  -t dufs:0.46.0-custom-v1 .
```

不会使用 `latest`，也不会推送 Docker Hub、GHCR 或其他外部 registry。
`dufs:0.46.0-custom-v1` 仅是指向已验证不可变风格本地镜像的便利 alias。

## OCI 元数据与核验

镜像包含 `org.opencontainers.image.title`、`version`、`revision`、`source`
和 `description`。`revision` 来自实际 Git SHA，不能包含密码、token 或其他
敏感信息。使用以下方式核验，而不向 scratch 镜像加入 shell：

```bash
docker image inspect dufs:0.46.0-custom-v1
docker history --no-trunc dufs:0.46.0-custom-v1
docker create --name dufs-phase6-inspect dufs:0.46.0-custom-v1
docker export dufs-phase6-inspect | tar -tf - | grep '^assets/'
docker rm dufs-phase6-inspect
```

Phase 2 的 `dufs:0.46.0-upstream-baseline-local` 是可追踪 baseline，Phase 6
不删除它。Phase 7 如需回滚镜像引用，应先停止并审查项目自己的 Compose 状态，
再将 `DUFS_IMAGE` 指回已验证标签；不执行 Docker 全局清理。
