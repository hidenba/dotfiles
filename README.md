# dotfiles

Arch Linux (Niri/Wayland) 環境の設定ファイル管理リポジトリ。

[GNU Stow](https://www.gnu.org/software/stow/) によるシンボリックリンク管理 + インストールスクリプトで、別PCへの環境復旧を自動化する。

## 環境

| 項目 | 値 |
|------|-----|
| OS | Arch Linux |
| WM | Niri (Wayland scrollable tiling) |
| モニター | LG 4K x3 (144Hz center + 60Hz left/right) |
| GPU | NVIDIA (proprietary) |
| Shell | zsh |
| Terminal | Alacritty |
| IME | Fcitx5 + Mozc |
| Audio | PipeWire + RNNoise |
| ディスク | LUKS + LVM + Btrfs (Snapper) |

## 構成

```
~/.dotfiles/
├── shell/              # .zshrc, .zshenv, .gitconfig
├── alacritty/          # Alacritty terminal
├── niri/               # Niri WM (3モニター、ワークスペース)
├── waybar/             # ステータスバー
├── pipewire/           # ノイズキャンセリング (RNNoise)
├── obs/                # OBS virtualcam toggle script
├── mako/               # 通知デーモン
├── fuzzel/             # アプリランチャー
├── swaylock/           # ロック画面
├── xremap/             # キーリマップ (CapsLock→Ctrl, Emacs風)
├── fcitx5/             # 日本語入力
├── wayland-flags/      # Chrome/Electron Waylandフラグ
├── git/                # global gitignore
├── systemd-user/       # ユーザーサービス
├── scripts/            # ~/.local/bin/ カスタムスクリプト
├── etc/                # /etc/ システム設定 (Stow対象外)
├── wallpaper/          # 壁紙 (デスクトップ、ロック画面、ログイン画面)
├── packages/           # pacman/AUR パッケージリスト
└── install.sh          # 環境構築スクリプト
```

## セットアップ

### 新規PCへのインストール

#### 前提: Arch Wiki の Installation Guide で以下を完了させる

##### 1. ライブUSBで起動

##### 2. パーティション作成

現環境のディスク構成:

```
nvme0n1             931.5G
├─nvme0n1p1           512M  EFI System Partition  → /boot
└─nvme0n1p2           931G  LUKS encrypted
  └─cryptlvm          931G  LVM
    ├─vg-swap            8G  swap
    └─vg-root          923G  Btrfs
```

```bash
# パーティション作成
gdisk /dev/nvme0n1
# n → +512M → ef00 (EFI System Partition)
# n → 残り全部 → 8309 (Linux LUKS)

# LUKS 暗号化
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptlvm

# LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm
lvcreate -L 8G vg -n swap
lvcreate -l 100%FREE vg -n root

# ファイルシステム
mkfs.fat -F32 /dev/nvme0n1p1
mkswap /dev/mapper/vg-swap
mkfs.btrfs /dev/mapper/vg-root
```

##### 3. Btrfs サブボリューム作成

```bash
mount /dev/mapper/vg-root /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log

umount /mnt
```

##### 4. マウント

```bash
# ルート
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@ /dev/mapper/vg-root /mnt

# サブボリューム
mkdir -p /mnt/{home,.snapshots,var/log,boot}
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@home /dev/mapper/vg-root /mnt/home
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@snapshots /dev/mapper/vg-root /mnt/.snapshots
mount -o noatime,compress=zstd:3,ssd,space_cache=v2,subvol=@var_log /dev/mapper/vg-root /mnt/var/log

# ESP + swap
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/mapper/vg-swap
```

##### 5. ベースシステムインストール

```bash
pacstrap /mnt base linux linux-firmware git vim sudo lvm2 btrfs-progs
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

##### 6. 基本設定 (chroot 内)

```bash
# タイムゾーン
ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
hwclock --systohc

# ロケール
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#ja_JP.UTF-8/ja_JP.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ホスト名
echo "tromania" > /etc/hostname

# root パスワード
passwd
```

##### 7. ユーザー作成

```bash
useradd -m -G wheel -s /bin/zsh hidenba
passwd hidenba
visudo  # %wheel ALL=(ALL:ALL) ALL のコメントを外す
```

##### 8. GRUB インストール (UEFI)

```bash
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# 最低限の GRUB 設定 (LUKS 解除に必要)
# GRUB_CMDLINE_LINUX に rd.luks.name=<UUID>=cryptlvm を設定
# UUID は blkid /dev/nvme0n1p2 で確認
vim /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
```

> install.sh Phase 3 で `etc/default/grub` を参照できるが、LUKS UUID と `rd.luks.options` (FIDO2) は
> PC固有なので手動編集が必要。既存の設定をテンプレートとして参考にすること。

##### 9. ネットワーク (systemd-networkd)

```bash
cat > /etc/systemd/network/20-wired.network << 'EOF'
[Match]
Name=en*

[Network]
DHCP=yes
EOF

systemctl enable systemd-networkd systemd-resolved
```

##### 10. initramfs

```bash
# /etc/mkinitcpio.conf の HOOKS に sd-encrypt と lvm2 を追加:
# HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block sd-encrypt lvm2 filesystems fsck)
vim /etc/mkinitcpio.conf
mkinitcpio -P
```

##### 11. 再起動

```bash
exit       # chroot を抜ける
umount -R /mnt
reboot
```

#### 再起動後、作成したユーザーでログインして実行

```bash
# 1. リポジトリをクローン (SSH鍵がまだないのでHTTPS)
git clone https://github.com/hidenba/dotfiles.git ~/.dotfiles

# 2. インストールスクリプトを実行
cd ~/.dotfiles
./install.sh

# 3. SSH鍵を設定したらリモートをSSHに切り替え
ssh-keygen -t ed25519
# → GitHubに公開鍵を登録
git remote set-url origin git@github.com:hidenba/dotfiles.git
```

#### install.sh の5フェーズ

1. **パッケージ** — pacman + paru(AUR) で一括インストール (`base`, `linux` 等も含むが `--needed` なので重複スキップ)
2. **Dotfiles** — `stow --restow` で全パッケージ展開 (壁紙含む)
3. **システム設定** — `/etc/` へdiff確認付きコピー + greetd壁紙配置
4. **サービス** — systemctl enable (bluetooth, docker, greetd, nvidia 等)
5. **ポストインストール** — mkinitcpio, grub-mkconfig, 手動手順リマインダー (YubiKey登録, Snapper, fstab, GRUB UUID)

### 既存環境への適用 (初回)

既にファイルが存在する場合は `--adopt` で既存ファイルをStow管理下に取り込む:

```bash
cd ~/.dotfiles
stow --adopt --target="$HOME" shell alacritty niri waybar ...
```

## 日常の操作

```bash
# 設定ファイルの編集 → そのまま反映される (シンボリックリンク)
vim ~/.config/niri/config.kdl   # 実体は ~/.dotfiles/niri/.config/niri/config.kdl

# 変更をコミット
cd ~/.dotfiles
git add -A && git commit -m "update niri config" && git push

# パッケージリスト更新
pacman -Qen | awk '{print $1}' > packages/pacman.txt
pacman -Qm  | awk '{print $1}' > packages/aur.txt

# 新しいアプリの設定を追加
mkdir -p newapp/.config/newapp
mv ~/.config/newapp/config newapp/.config/newapp/
stow --target="$HOME" newapp
```

## YubiKey (FIDO2/U2F) 認証

YubiKeyタッチによるパスワードレス認証を3層で使用している:

### 1. ディスク暗号化解除 (LUKS + FIDO2)

起動時にYubiKeyタッチでLUKSボリュームをアンロックする。

| 項目 | 値 |
|------|-----|
| 方式 | LUKS2 + systemd-fido2 トークン |
| Keyslot 0 | パスワード (フォールバック) |
| Keyslot 1 | FIDO2 (YubiKey) |
| GRUB | `rd.luks.options=<UUID>=fido2-device=auto` |
| initramfs | `sd-encrypt` hook (systemd-based) |

**振る舞い**: 起動時にYubiKeyが接続されていればタッチでアンロック。未接続時はパスワード入力にフォールバック。

**関連ファイル**:
- `etc/default/grub` — `GRUB_CMDLINE_LINUX` に `rd.luks.name=<UUID>=cryptlvm` と `rd.luks.options=<UUID>=fido2-device=auto`
- `etc/mkinitcpio.conf` — HOOKS に `sd-encrypt lvm2`、MODULES に `nvidia nvidia_modeset nvidia_uvm nvidia_drm usbhid xhci_hcd`

### 2. ログイン / 画面ロック / 特権操作 (PAM + U2F)

| 場面 | PAM設定 | 振る舞い |
|------|---------|---------|
| ログイン (greetd) | `etc/pam.d/greetd` | YubiKeyタッチで認証。未接続時はパスワードにフォールバック |
| 画面ロック解除 (swaylock) | `etc/pam.d/swaylock` | 同上 |
| 特権操作 (polkit) | `etc/pam.d/polkit-1` | 同上 |

**PAMルール**:

```
auth [success=done default=ignore] pam_u2f.so cue origin=pam://tromania appid=pam://tromania
auth include system-auth   (or login)
```

- `[success=done default=ignore]` — YubiKeyタッチ成功で即認証完了。キーが未接続 or タッチしなかった場合は無視して次のルール（パスワード認証）へフォールバック
- `cue` — "Please touch the device" プロンプトを表示
- `origin` / `appid` — ホスト名ベース (`pam://tromania`)。新PCではホスト名に合わせて書き換える

### 新規PCでのセットアップ手順

```bash
# --- LUKS FIDO2 登録 ---

# 1. LUKSパーティションにFIDO2トークンを登録
sudo systemd-cryptenroll /dev/<partition> --fido2-device=auto

# 2. /etc/default/grub を編集して新UUIDに書き換え
#    rd.luks.name=<新UUID>=cryptlvm rd.luks.options=<新UUID>=fido2-device=auto

# 3. initramfs と GRUB を再生成
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg

# --- PAM U2F 登録 ---

# 4. パッケージインストール (install.sh Phase 1 で入る)
sudo pacman -S pam-u2f

# 5. YubiKeyを挿してキーを登録
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys

# 6. バックアップキーを追加登録する場合
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys

# 7. PAM設定のホスト名を書き換え (ホスト名が異なる場合)
# etc/pam.d/ 内の origin=pam://tromania appid=pam://tromania を
# 新ホスト名に置換してから install.sh Phase 3 でコピー
```

### セキュリティ上の注意

- `~/.config/Yubico/u2f_keys` はデバイス固有の公開鍵情報を含むため **Gitに含めない** (`.gitignore`済み)
- LUKS の FIDO2 credential もデバイス固有 — 新PCでは `systemd-cryptenroll` で再登録が必要
- すべての認証ポイントでパスワードフォールバックを維持し、YubiKey紛失時のロックアウトを防止

## 壁紙

`wallpaper/` はStowパッケージとして `~/Pictures/wallpaper/` にシンボリックリンク展開される。

| ファイル | 展開先 | 用途 |
|---------|--------|------|
| `wallpaper.png` | `~/Pictures/wallpaper/wallpaper.png` | デスクトップ背景 (swaybg) |
| `lock_bg.png` | `~/Pictures/wallpaper/lock_bg.png` | swaylock ロック画面 |

greetd ログイン画面の壁紙は greeter ユーザーが `~/` にアクセスできないため、install.sh Phase 3 で `/usr/share/backgrounds/lock_bg.png` にコピーする。

壁紙を変更する場合は `wallpaper/Pictures/wallpaper/` 内のファイルを差し替えてコミットする。

## Snapper (Btrfs スナップショット)

Btrfs スナップショットによるシステムのロールバック環境。

### 構成

| パッケージ | 役割 |
|-----------|------|
| `snapper` | スナップショット管理 |
| `snap-pac` | pacman フック — パッケージ操作ごとに pre/post スナップショットを自動作成 |
| `grub-btrfs` | GRUB メニューにスナップショットを表示 → そこから起動してロールバック可能 |

### 保持ポリシー

| 種別 | 保持数 |
|------|-------|
| hourly | 5 |
| daily | 7 |
| weekly | 2 |
| monthly | 1 |
| yearly | 10 |
| number (pacman pre/post) | 50 |

### 新規PCでのセットアップ手順

install.sh Phase 1 で `snapper`, `snap-pac`, `grub-btrfs` がインストールされる。
Phase 4 で `snapper-timeline.timer`, `snapper-cleanup.timer` が有効化される。
以下は手動で実行する:

```bash
# 1. @snapshots サブボリュームが /.snapshots にマウント済みであることを確認
#    (前提: fstab で subvol=@snapshots → /.snapshots をマウント済み)

# 2. snapper が /.snapshots を自動作成しようとするので、先に umount してディレクトリを消す
sudo umount /.snapshots
sudo rmdir /.snapshots

# 3. snapper config 作成 (/.snapshots サブボリュームが自動作成される)
sudo snapper -c root create-config /

# 4. snapper が作った /.snapshots サブボリュームを削除し、@snapshots を使う
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a   # fstab の @snapshots が /.snapshots にマウントされる

# 5. パーミッション設定
sudo chmod 750 /.snapshots

# 6. 保持ポリシー設定
sudo snapper -c root set-config \
  TIMELINE_CREATE=yes \
  TIMELINE_LIMIT_HOURLY=5 \
  TIMELINE_LIMIT_DAILY=7 \
  TIMELINE_LIMIT_WEEKLY=2 \
  TIMELINE_LIMIT_MONTHLY=1 \
  TIMELINE_LIMIT_YEARLY=10 \
  NUMBER_LIMIT=50

# 7. GRUB にスナップショットを反映
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### 日常操作

```bash
snapper list                              # スナップショット一覧
snapper status <pre_num>..<post_num>      # pre/post 間の変更ファイル一覧
snapper diff <pre_num>..<post_num> <file> # 特定ファイルの差分
snapper undochange <pre_num>..<post_num>  # 変更をロールバック (部分的)
```

### ロールバック手順

Arch では `snapper rollback` は使えない。ルートサブボリューム `@` を手動で差し替える必要がある。

#### A. システムが起動できる場合 — 部分ロールバック

pacman 操作を取り消すだけなら `undochange` で十分:

```bash
# 例: snap-pac の pre=206, post=207 の間の変更を巻き戻す
sudo snapper undochange 206..207
```

#### B. システムが起動できない場合 — フルロールバック

##### 方法1: grub-btrfs でスナップショットから起動して復旧

1. GRUB メニューで「Arch Linux snapshots」を選択
2. 戻したいスナップショットを選んで起動 (read-only で起動する)
3. 起動できたら、以下で `@` を差し替え:

```bash
# Btrfs トップレベル (subvolid=5) をマウント
sudo mount -o subvolid=5 /dev/mapper/vg-root /mnt

# 壊れた @ を退避
sudo mv /mnt/@ /mnt/@_broken

# スナップショットから新しい @ を read-write で作成
# <num> は戻したいスナップショット番号
sudo btrfs subvolume snapshot /mnt/@snapshots/<num>/snapshot /mnt/@

# 退避した @_broken は確認後に削除
# sudo btrfs subvolume delete /mnt/@_broken

sudo umount /mnt
sudo reboot
```

##### 方法2: ライブUSBから復旧

1. ライブUSBで起動
2. LUKS + LVM を開く:

```bash
cryptsetup open /dev/nvme0n1p2 cryptlvm
# Btrfs トップレベルをマウント
mount -o subvolid=5 /dev/mapper/vg-root /mnt
```

3. 以降は方法1のステップ3と同じ (`mv @`, `btrfs subvolume snapshot`)

#### 注意事項

- `@home`, `@var_log` は `@` とは別サブボリュームなので、ルートのロールバックの影響を受けない
- `@snapshots` も独立しているので、ロールバック後もスナップショット一覧は維持される
- fstab と GRUB で `subvol=/@` を明示指定しているため、default subvolume の設定に依存しない

## その他の注意事項

- `fstab`, `grub` のUUIDはPC固有 → install.shではスキップ、手動設定
- OBSのシーン/プロファイルは追跡しない（ランタイム状態）
