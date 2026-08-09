# 自定义镜像构建

`Dockerfile.custom` 保留官方 amd64 Rust musl 多阶段构建和 scratch runtime。
最终层只包含 `/bin/dufs`、`/assets/` 与 OCI metadata；不会复制 runtime
`.env`、config、data、logs、backup 或凭据。

`/assets/` 来自 `custom/assets/`，可在没有宿主机挂载时提供 Custom UI V1。
生产 runtime 的 `/home/ldzcyh/dockerApps/dufs/assets:/assets:ro` 可覆盖它，
Compose 使用 `--assets /assets`。

## Phase 6.1 已验证构建

镜像从已提交构建状态 `faca49a59b6cfdf4a9331451355fc10e32a6f8b3` 生成：

```bash
docker build --platform linux/amd64 -f Dockerfile.custom \
  --build-arg IMAGE_VERSION=0.46.0-custom-v1-faca49a \
  --build-arg VCS_REF=faca49a59b6cfdf4a9331451355fc10e32a6f8b3 \
  -t dufs:0.46.0-custom-v1-faca49a \
  -t dufs:0.46.0-custom-v1 .
```

不可变风格 tag 为 `dufs:0.46.0-custom-v1-faca49a`；alias 仅用于本地
便利引用，不使用 `latest`，也不推送外部 registry。OCI labels 包含
`org.opencontainers.image.title`、`version`、`revision`、`source`、
`description`，且不得包含 secret。

使用 `docker image inspect`、`docker history --no-trunc` 与临时
`docker create`/`docker export` 验证镜像；不得为了检查 scratch runtime
而添加 shell。Phase 2 baseline image 保留。旧
`dufs:0.46.0-custom-v1-153a36f` 是 superseded local candidate，保留审计，
Phase 7 不得引用。

## Production V1.0 Release Provenance

Production V1.0 的 Git release tag 是 `production-v1.0.0`，它指向 Phase 9 的
documentation/release closeout commit。该 tag 不等同于 Docker image tag；已经完成
Phase 8 acceptance 的 production image 仍从
`faca49a59b6cfdf4a9331451355fc10e32a6f8b3` 构建，OCI revision 也继续为该真正的
image source revision。Phase 9 未重建镜像，避免将未经验收的文档 commit 误称为 image
provenance。
