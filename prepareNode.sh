#!/bin/sh

## v0.1 - Robert Jan de Groot - initial version (tested on CENTOS 7.6)

## export DEBUG=TRUE to run debug info
debug () {
message=$1
if [ "${DEBUG}" = "TRUE" ]; then
  echo "  [DEBUG] ${message}" | tee --append ${diagfile}
fi
}


prereq () {

logfile="/tmp/prepareNode-$(date +%Y%m%d-%H%M%S).log"
diagfile="/tmp/prepareNode-$(date +%Y%m%d-%H%M%S)-diagnostic.log"

if [ "$(whoami)" = "root" ]; then
  prefix=""
  debug "user is root"
else
  prefix="sudo"
  debug "user is not root"
  id=$(id)
  if [ $(echo ${id}|grep -c wheel) -eq 0 ]; then
    echo "you are not root and you're not in the wheel group"
    echo "not enought privileges!"
    exit 1
  fi
fi

debug "prefix set to ${prefix}"

if [ ! -f ./package.lst ]; then
  echo "cannot find property file!"
  exit 1
fi

}

verifyCommand () {
lastExit=$?
command=$1
if [ ${lastExit} -eq 0 ]; then
  echo "${command} succeeded" | tee --append ${logfile}
else
  echo "${command} failed!" | tee --append ${logfile}
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

## start networkmanager
${prefix} systemctl start NetworkManager
verifyCommand "starting NetworkManager"
}

installDocker () {
  echo "installing docker"
  ${prefix} yum -y install docker-1.13.1
  verifyCommand "installing Docker"

  ## this contains a dangerous assumption that the empty docker disk is the last one in lsblk
  disk=`lsblk | tail -n 1 | awk '{ print $1 }'`

  ## update docker config if needed
  if [ $(grep -c "insecure" /etc/sysconfig/docker) -eq 0 ]; then
    ${prefix} sed -i "s|^OPTIONS='|OPTIONS='--insecure-registry=172.30.0.0/16 |g" /etc/sysconfig/docker
    verifyCommand "setting insecure registry"
  fi

  ## if docker-vg doesnt exist yet, create it
  if [ $(${prefix} vgdisplay | grep -c "docker-vg") -eq 0 ]; then
    debug "docker-vg doesnt exist yet, creating"
    echo "DEVS=${disk}" | ${prefix} tee --append /etc/sysconfig/docker-storage-setup
    echo "VG=docker-vg" | ${prefix} tee --append /etc/sysconfig/docker-storage-setup
    verifyCommand "preparing docker storage"

    ${prefix} docker-storage-setup
    verifyCommand "setting up Docker storage"
  else
    debug "docker-vg already created"
  fi

  ${prefix} systemctl enable docker

}

installEPEL () {

  ${prefix} yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  verifyCommand "setting up the EPEL release"
  ${prefix} sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo
  verifyCommand "disabling the EPEL repo"
  ${prefix} yum -y --enablerepo=epel install ansible pyOpenSSL
  verifyCommand "installing Ansible"
}

printResult () {
  echo "--------script completed--------"
  echo "you can find the log in: ${logfile}"
  if [ "${DEBUG}" == "TRUE" ]; then
    echo "you can find the debug log in ${diagfile}"
  fi
}

runAll () {
  prereq;
  installPackages;
  installDocker;
  installEPEL;
  printResult;
}

runAll;
