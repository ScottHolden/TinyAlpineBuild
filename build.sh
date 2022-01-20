#!/bin/bash

set -e

readonly ALPINE_KEYS='
alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub:MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1yHJxQgsHQREclQu4Ohe\nqxTxd1tHcNnvnQTu/UrTky8wWvgXT+jpveroeWWnzmsYlDI93eLI2ORakxb3gA2O\nQ0Ry4ws8vhaxLQGC74uQR5+/yYrLuTKydFzuPaS1dK19qJPXB8GMdmFOijnXX4SA\njixuHLe1WW7kZVtjL7nufvpXkWBGjsfrvskdNA/5MfxAeBbqPgaq0QMEfxMAn6/R\nL5kNepi/Vr4S39Xvf2DzWkTLEK8pcnjNkt9/aafhWqFVW7m3HCAII6h/qlQNQKSo\nGuH34Q8GsFG30izUENV9avY7hSLq7nggsvknlNBZtFUcmGoQrtx3FmyYsIC8/R+B\nywIDAQAB
alpine-devel@lists.alpinelinux.org-5261cecb.rsa.pub:MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwlzMkl7b5PBdfMzGdCT0\ncGloRr5xGgVmsdq5EtJvFkFAiN8Ac9MCFy/vAFmS8/7ZaGOXoCDWbYVLTLOO2qtX\nyHRl+7fJVh2N6qrDDFPmdgCi8NaE+3rITWXGrrQ1spJ0B6HIzTDNEjRKnD4xyg4j\ng01FMcJTU6E+V2JBY45CKN9dWr1JDM/nei/Pf0byBJlMp/mSSfjodykmz4Oe13xB\nCa1WTwgFykKYthoLGYrmo+LKIGpMoeEbY1kuUe04UiDe47l6Oggwnl+8XD1MeRWY\nsWgj8sF4dTcSfCMavK4zHRFFQbGp/YFJ/Ww6U9lA3Vq0wyEI6MCMQnoSMFwrbgZw\nwwIDAQAB
alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub:MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAutQkua2CAig4VFSJ7v54\nALyu/J1WB3oni7qwCZD3veURw7HxpNAj9hR+S5N/pNeZgubQvJWyaPuQDm7PTs1+\ntFGiYNfAsiibX6Rv0wci3M+z2XEVAeR9Vzg6v4qoofDyoTbovn2LztaNEjTkB+oK\ntlvpNhg1zhou0jDVYFniEXvzjckxswHVb8cT0OMTKHALyLPrPOJzVtM9C1ew2Nnc\n3848xLiApMu3NBk0JqfcS3Bo5Y2b1FRVBvdt+2gFoKZix1MnZdAEZ8xQzL/a0YS5\nHd0wj5+EEKHfOd3A75uPa/WQmA+o0cBFfrzm69QDcSJSwGpzWrD1ScH3AK8nWvoj\nv7e9gukK/9yl1b4fQQ00vttwJPSgm9EnfPHLAtgXkRloI27H6/PuLoNvSAMQwuCD\nhQRlyGLPBETKkHeodfLoULjhDi1K2gKJTMhtbnUcAA7nEphkMhPWkBpgFdrH+5z4\nLxy+3ek0cqcI7K68EtrffU8jtUj9LFTUC8dERaIBs7NgQ/LfDbDfGh9g6qVj1hZl\nk9aaIPTm/xsi8v3u+0qaq7KzIBc9s59JOoA8TlpOaYdVgSQhHHLBaahOuAigH+VI\nisbC9vmqsThF2QdDtQt37keuqoda2E6sL7PUvIyVXDRfwX7uMDjlzTxHTymvq2Ck\nhtBqojBnThmjJQFgZXocHG8CAwEAAQ==
'
ALPINE_BRANCH="latest-stable"
ALPINE_MIRROR="http://dl-cdn.alpinelinux.org/alpine"
APK_TOOLS_URI="https://github.com/alpinelinux/apk-tools/releases/download/v2.10.4/apk-tools-2.10.4-x86_64-linux.tar.gz"
APK_TOOLS_SHA256="efe948160317fe78058e207554d0d9195a3dfcc35f77df278d30448d7b3eb892"

IMAGE_NAME="demo"
RAW_PATH="./$IMAGE_NAME.raw"
MOUNT_PATH="./$IMAGE_NAME"
VHD_PATH="./$IMAGE_NAME.vhd"
DISK_SIZE_MB="200" #1024

wget -T 10 --no-verbose "$APK_TOOLS_URI"
echo "$APK_TOOLS_SHA256 ${APK_TOOLS_URI##*/}" | sha256sum -c
tar -xzf "${APK_TOOLS_URI##*/}"

APK="$(ls apk-tools-*/apk)"

#apk add e2fsprogs

dd if=/dev/zero of=$RAW_PATH bs=1M count=$DISK_SIZE_MB
mkfs.ext4 -L root -O ^64bit -E nodiscard $RAW_PATH
mkdir -p $MOUNT_PATH
mount -o loop $RAW_PATH $MOUNT_PATH

ROOT_UUID="$(findmnt $MOUNT_PATH -o UUID -n)"

mkdir -p $MOUNT_PATH/etc/apk/keys

cat > $MOUNT_PATH/etc/apk/repositories <<-EOF
$ALPINE_MIRROR/$ALPINE_BRANCH/main
$ALPINE_MIRROR/$ALPINE_BRANCH/community
EOF

for line in $ALPINE_KEYS; do
  printf -- "-----BEGIN PUBLIC KEY-----\n${line#*:}\n-----END PUBLIC KEY-----\n" > "$MOUNT_PATH/etc/apk/keys/${line%%:*}"
done

$APK --no-progress add --root $MOUNT_PATH --update-cache --initdb alpine-base

mkdir -p "$MOUNT_PATH"/proc
mount -t proc none "$MOUNT_PATH"/proc

mkdir -p "$MOUNT_PATH"/dev
mount --bind /dev "$MOUNT_PATH"/dev
mount --make-private "$MOUNT_PATH"/dev

mkdir -p "$MOUNT_PATH"/sys
mount --bind /sys "$MOUNT_PATH"/sys
mount --make-private "$MOUNT_PATH"/sys

install -D -m 644 /etc/resolv.conf "$MOUNT_PATH"/etc/resolv.conf

$APK --no-progress add --root $MOUNT_PATH mkinitfs

cat > "$MOUNT_PATH"/etc/mkinitfs/mkinitfs.conf <<-EOF
features="base ext4 scsi virtio"
EOF

$APK --no-progress add --root $MOUNT_PATH linux-virt

$APK --no-progress add --root $MOUNT_PATH --no-scripts syslinux

$APK --no-progress search --root $MOUNT_PATH --exact --quiet linux-lts | grep -q . && default_kernel='lts' || default_kernel='vanilla'

sed -Ei \
  -e "s|^[# ]*(root)=.*|\1=UUID=$ROOT_UUID|" \
  -e "s|^[# ]*(modules)=.*|\1=ext4|" \
  -e "s|^[# ]*(default)=.*|\1=$default_kernel|" \
  "$MOUNT_PATH"/etc/update-extlinux.conf

chroot "$MOUNT_PATH" extlinux --install /boot

chroot "$MOUNT_PATH" update-extlinux --warn-only 2>&1 | grep -Fv 'extlinux: cannot open device /dev' >&2

cat > "$MOUNT_PATH"/etc/fstab <<-EOF
# <fs> <mountpoint> <type> <opts> <dump/pass>
UUID=$ROOT_UUID / ext4 noatime 0 1
EOF

mkdir -p "$MOUNT_PATH"/etc/runlevels/sysinit

ln -s /etc/init.d/devfs "$MOUNT_PATH"/etc/runlevels/sysinit/devfs
ln -s /etc/init.d/dmesg "$MOUNT_PATH"/etc/runlevels/sysinit/dmesg
ln -s /etc/init.d/mdev "$MOUNT_PATH"/etc/runlevels/sysinit/mdev
ln -s /etc/init.d/hwdrivers "$MOUNT_PATH"/etc/runlevels/sysinit/hwdrivers
ln -s /etc/init.d/cgroups "$MOUNT_PATH"/etc/runlevels/sysinit/cgroups

mkdir -p "$MOUNT_PATH"/etc/runlevels/boot

ln -s /etc/init.d/modules "$MOUNT_PATH"/etc/runlevels/boot/modules
ln -s /etc/init.d/hwclock "$MOUNT_PATH"/etc/runlevels/boot/hwclock
ln -s /etc/init.d/swap "$MOUNT_PATH"/etc/runlevels/boot/swap
ln -s /etc/init.d/hostname "$MOUNT_PATH"/etc/runlevels/boot/hostname
ln -s /etc/init.d/sysctl "$MOUNT_PATH"/etc/runlevels/boot/sysctl
ln -s /etc/init.d/bootmisc "$MOUNT_PATH"/etc/runlevels/boot/bootmisc
ln -s /etc/init.d/syslog "$MOUNT_PATH"/etc/runlevels/boot/syslog

mkdir -p "$MOUNT_PATH"/etc/runlevels/shutdown

ln -s /etc/init.d/killprocs "$MOUNT_PATH"/etc/runlevels/shutdown/killprocs
ln -s /etc/init.d/savecache "$MOUNT_PATH"/etc/runlevels/shutdown/savecache
ln -s /etc/init.d/mount-ro "$MOUNT_PATH"/etc/runlevels/shutdown/mount-ro

#Packages/Config/Scripts here!

umount "$MOUNT_PATH"/proc
umount "$MOUNT_PATH"/dev
umount "$MOUNT_PATH"/sys
umount "$MOUNT_PATH"
rmdir "$MOUNT_PATH"
rm -rf apk-tools-*

qemu-img convert -f raw -O vpc -o subformat=fixed,force_size $RAW_PATH $VHD_PATH

rm $RAW_PATH