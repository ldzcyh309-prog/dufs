# DUFS Backup / Restore

## 备份内容与 secret 策略

`scripts/backup.sh` 生成 `tar.gz` archive、`manifest.txt` 和同名 `.sha256`。
默认包含 `compose.yaml`、config、assets 和 data；不包含 runtime `.env`、logs、旧
backup。这样普通备份不会保存管理员认证 hash。使用 `--data-path 相对路径` 可只备份
指定 data 路径，适合验收。

archive 与 checksum 的权限为 0600。manifest 仅记录 format version、创建时间、
DUFS image、source Git revision 和组件清单，不记录 secret。

## 验证与隔离恢复

```text
scripts/restore.sh --verify BACKUP
scripts/restore.sh --list BACKUP
scripts/restore.sh --target /tmp/dufs-restore BACKUP
```

restore 验证 checksum、manifest 和 archive member，拒绝绝对路径、traversal、
symlink/hardlink、device、FIFO 及未知成员。target 必须显式、为空，且不能是 `/`、
`/home`、dockerApps 或 production runtime 路径。恢复 owner/group 依据 runtime
`DUFS_UID`/`DUFS_GID`，不使用 `chmod 777`。

## Selective production restore

```text
scripts/restore.sh --production-path .dufs-phase8-acceptance --apply BACKUP
```

仅允许 data 内的安全相对路径；目标必须不存在，因此默认不覆盖。该模式不恢复 `.env`，
不停止 container，不触碰其他 Compose project。Phase 8 仅允许对专用验收路径使用它。

## 完整 production restore

完整 production restore 属于高风险人工运维，不由此脚本自动执行。应先创建新的备份，
使用 staging 审核、明确确认，并保持旧数据可恢复；不得直接删除 production data。

## 验收状态

Phase 8 已通过 backup、manifest、checksum、verify/list、isolated restore 与 selective
production-path restore；中文文件名、binary integrity、ownership 和 DUFS 重新读取
恢复内容均通过。完整 production disaster restore 作为人工高风险流程保留，不是验收
FAIL 条件。
