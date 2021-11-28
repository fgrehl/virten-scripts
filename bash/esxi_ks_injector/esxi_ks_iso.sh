#!/bin/bash
# Add kickstart configuration to ESXi ISO for automated installation.
#
# Example:
# ./esxi_ks_iso.sh -i VMware-VMvisor-Installer-7.0U2-17630552.x86_64.iso -k KS.CFG

# Check if genisoimage is installed
command -v genisoimage >/dev/null 2>&1 || { echo >&2 "This script requires genisoimage but it's not installed."; exit 1; }

# Script must be started as root to allow iso mounting
if [ "$EUID" -ne 0 ] ; then echo "Please run as root." ;  exit 1 ;  fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -i|--iso) BASEISO="$2"; shift ;;
    -k|--ks) KS="$2"; shift ;;
    -w|--working-dir) WORKINGDIR="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z $BASEISO || -z $KS ]]; then
 echo 'Usage: esxi_ks_iso.sh -i VMware-VMvisor-Installer-7.0U2-17630552.x86_64.iso -k KS.CFG'
 echo 'Options:'
 echo "  -i, --iso          Base ISO File"
 echo '  -k, --ks           Kickstart Configuration File'
 echo '  -w, --working-dir  Working directory (Optional)'
 exit 1
fi

if [[ -z $WORKINGDIR ]]; then
  WORKINGDIR="/dev/shm/esxibuilder"
fi

mkdir -p ${WORKINGDIR}/iso
mount -t iso9660 -o loop,ro ${BASEISO} ${WORKINGDIR}/iso

mkdir -p ${WORKINGDIR}/isobuild
cp ${KS} ${WORKINGDIR}/isobuild/KS.CFG
cd ${WORKINGDIR}/iso
tar cf - . | (cd ${WORKINGDIR}/isobuild; tar xfp -)

chmod +w ${WORKINGDIR}/isobuild/boot.cfg
chmod +w ${WORKINGDIR}/isobuild/efi/boot/boot.cfg
sed -i -e 's/cdromBoot/ks=cdrom:\/KS.CFG/g'  ${WORKINGDIR}/isobuild/boot.cfg
sed -i -e 's/cdromBoot/ks=cdrom:\/KS.CFG/g'  ${WORKINGDIR}/isobuild/efi/boot/boot.cfg

cd ${WORKINGDIR}
genisoimage -relaxed-filenames -J -R -o esxi-ks.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -eltorito-boot efiboot.img -quiet --no-emul-boot ${WORKINGDIR}/isobuild  2>/dev/null
echo "ISO saved at ${WORKINGDIR}/esxi-ks.iso"

umount ${WORKINGDIR}/iso
rm -rf ${WORKINGDIR}/iso
rm -rf ${WORKINGDIR}/isobuild
