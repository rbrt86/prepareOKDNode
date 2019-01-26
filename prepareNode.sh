#!/bin/sh

## v0.1 - Robert Jan de Groot - initial version

prereq () {
if [ "$(whoami)" = "root" ]; then
  su=true
  prefix=""
else
  prefix="sudo"
  su=false
  id=$(id)
  if [ $(echo ${id}|grep -c wheel) -eq 0 ]; then
    echo "you are not root and you're not in the wheel group"
    echo "not enought privileges!"
    #exit 1
  fi
fi

if [ ! -f ./package.lst ]; then
  echo "cannot find property file!"
  exit 1
fi

}

verifyCommand () {
lastExit=$?
command=$1
if [ ${lastExit} -eq 0 ]; then
  echo "${command} succeeded"
else
  echo "${command} failed!"
  exit 1
fi

}

installPackages () {
cat ./package.lst | grep -v '#'| while read package
do
  echo "installing ${package}"
  ${prefix} yum -y install ${package}
  verifyCommand "installing ${package}"
done

## enable networkmanager
${prefix} systemctl enable NetworkManager
verifyCommand "enabling NetworkManager on boot"
}

installDocker () {
  echo "installing docker"
  ${prefix} yum -y install docker-1.13.1

  ## this contains a dangerous assumption that the empty docker disk is the last one in lsblk
  disk=`lsblk | tail -n 1 | awk '{ print $1 }'`

  ${prefix} echo "DEVS=${disk}" >> /etc/sysconfig/docker-storage-setup
  ${prefix} echo "VG=docker-vg" >> /etc/sysconfig/docker-storage-setup

  ${prefix} docker-storage-setup
  verifyCommand "setting up Docker storage"

  ${prefix} systemctl enable docker

}

installEPEL () {

  ${prefix} yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  ${prefix} sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo
  ${prefix} yum -y --enablerepo=epel install ansible pyOpenSSL
}

runAll () {
  prereq;
  installPackages;
  installDocker;
  installEPEL;
}

runAll;
