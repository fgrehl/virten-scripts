#!/bin/bash
# Add kickstart configuration to ESXi ISO for automated installation.
#
# Example:
# ./esxi_customks_iso.sh -i VMware-VMvisor-Installer-7.0U2-17630552.x86_64.iso -k KS-TEMPLATE.CFG \
#                        -a 192.168.0.10 -m 255.255.255.0 -g 192.168.0.1 -n esx1.virten.lab -v 0 -d 192.168.0.1

# Check if genisoimage is installed
command -v genisoimage >/dev/null 2>&1 || { echo >&2 "This script requires genisoimage but it's not installed."; exit 1; }

# Script must be started as root to allow iso mounting
if [ "$EUID" -ne 0 ] ; then echo "Please run as root." ;  exit 1 ;  fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -i|--iso) BASEISO="$2"; shift ;;
    -k|--ks) KS="$2"; shift ;;
    -w|--working-dir) WORKINGDIR="$2"; shift ;;
    -a|--ip-address) KSIPADDRESS="$2"; shift ;;
    -m|--netmask) KSNETMASK="$2"; shift ;;
    -g|--gateway) KSGATEWAY="$2"; shift ;;
    -n|--hostname) KSHOSTNAME="$2"; shift ;;
    -v|--vlan) KSVLAN="$2"; shift ;;
    -d|--dns) KSNAMESERVER="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z $BASEISO || -z $KS || -z $KSIPADDRESS || -z $KSNETMASK || -z $KSGATEWAY || -z $KSHOSTNAME || -z $KSVLAN || -z $KSNAMESERVER ]]; then
 echo 'Usage: esxi_customks_iso.sh -i VMware-VMvisor-Installer-7.0U2-17630552.x86_64.iso -k KS-TEMPLATE.CFG \'
 echo '                            -a 192.168.0.10 -m 255.255.255.0 -g 192.168.0.1 -n esx1.virten.lab -v 0 -d 192.168.0.1'
 echo 'Options:'
 echo "  -i, --iso          Base ISO File"
 echo '  -k, --ks           Kickstart Configuration File'
 echo '  -w, --working-dir  Working directory (Optional)'
 echo '  -a, --ip-address   ESXi IP Address'
 echo '  -m, --netmask      ESXi Subnet Mask ' 
 echo '  -g, --gateway      ESXi Gateway'
 echo '  -n, --hostname     ESXi Hostname'
 echo '  -v, --vlan         ESXi VLAN ID (0 for None) '
 echo '  -d, --dns          ESXi DNS Server'
 exit 1
fi

if [[ -z $WORKINGDIR ]]; then
  WORKINGDIR="/dev/shm/esxibuilder"
fi

printf "=== Base ISO: %s ===\n" "$BASEISO"
printf "=== ESXi KS Configuration ===\n"
printf "IP Address: %s\n" "$KSIPADDRESS"
printf "Netmask: %s\n" "$KSNETMASK"
printf "Gateway: %s\n" "$KSGATEWAY"
printf "Hostname: %s\n" "$KSHOSTNAME"
printf "VLAN: %s\n" "$KSVLAN"


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
sed -i -e 's/KSIPADDRESS/'"$KSIPADDRESS"'/g'  ${WORKINGDIR}/isobuild/KS.CFG
sed -i -e 's/KSNETMASK/'"$KSNETMASK"'/g'  ${WORKINGDIR}/isobuild/KS.CFG
sed -i -e 's/KSGATEWAY/'"$KSGATEWAY"'/g'  ${WORKINGDIR}/isobuild/KS.CFG
sed -i -e 's/KSHOSTNAME/'"$KSHOSTNAME"'/g'  ${WORKINGDIR}/isobuild/KS.CFG
sed -i -e 's/KSVLAN/'"$KSVLAN"'/g'  ${WORKINGDIR}/isobuild/KS.CFG
sed -i -e 's/KSNAMESERVER/'"$KSNAMESERVER"'/g'  ${WORKINGDIR}/isobuild/KS.CFG

cd ${WORKINGDIR}
genisoimage -relaxed-filenames -J -R -o ${KSHOSTNAME}.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -eltorito-boot efiboot.img -quiet -no-emul-boot ${WORKINGDIR}/isobuild  2>/dev/null
echo "ISO saved at ${WORKINGDIR}/${KSHOSTNAME}.iso"

umount ${WORKINGDIR}/iso
rm -rf ${WORKINGDIR}/iso
rm -rf ${WORKINGDIR}/isobuild
