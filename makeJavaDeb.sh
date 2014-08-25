#!/usr/bin/env bash
## Name:   makeJavaDeb.sh
## Author: Jim T. Tang(maxubuntu@gmail.com)
## Date:   2014.02.28
## Description: This script is to help Debian/Ubuntu-like users 
## to install Oracle JDK/JRE in a more practical way.
## Usage:  makeJavaDeb.sh jre-8u5-linux-x64.tar.gz
## Suits:  Oracle JDK/JRE 1.7/1.8
## No confliction with OpenJDK nor each other. You can switch different
## version of java/javac by invoking "update-alternatives".

#################
## file reader ##
#################
if [ "$1" == "" ]; then
	read -p "please specify path to the jre/jdk tarball: " filename
	filename=$filename
else
	filename=$1
fi
echo $filename | grep "tar.gz" >/dev/null 2>&1
[ $? -eq 0 ] || { echo "suffix must be in tar.gz. exit now."; exit 2; }

file --mime-type -b $filename | grep gzip >/dev/null 2>&1
[ $? -eq 0 ] || { echo "MIME type must be in gzip. exit now."; exit 2; }
##################
## bold setting ##
##################
bold=`tput bold`
normal=`tput sgr0`

###########################
## file name transformer ##
###########################
## jdk-7u51-linux-x64.tar.gz -- > oracle-jdk_1.7.0_51_amd64.deb
## jre-8u5-linux-x64.tar.gz -- > oracle-jre_1.8.0_5_amd64.deb
## server-jre-8u5-linux-x64.tar.gz -- > oracle-server-jre_1.8.0_5_amd64.deb
file=$(basename $filename)
shortVersion=$(echo $file | awk -F'-' '{print $(NF-2)}')
java=$(echo $file | awk -F"-$shortVersion" '{print $1}')
version=$(echo $shortVersion | awk -F'u' '{print $1}')
if [ ${version} == "7" ]; then
   priority=20007
else
   priority=20008
fi
release=$(echo $shortVersion | awk -F'u' '{print $2}')
ARCH=$(echo $file | awk -F'-' '{print $NF}'| sed 's/.tar.gz//')
if [ "$ARCH" == "x64" ]; then
	arch="amd64"
	multiarch=x86_64-linux-gnu
else
	arch="i586"
	multiarch=i386-linux-gnu
fi
dirName="oracle-${java}_1.${version}.0_${release}_${arch}"
dataDir=$(tar -tf $filename | head -n1|awk -F/ '{print $1}')
#################
## preparation ##
#################
[ ! -d "$dirName" ] && {
	mkdir -p $dirName/DEBIAN
} || {
	echo $dirName exists. Mission aborts.
	exit 0;
}

####################################
## copy contents and build deb... ##
####################################
echo -n "${bold}Phase1: copying files...${normal}"
mkdir -p $dirName/usr/lib/jvm
tar zxf $filename -C $dirName/usr/lib/jvm
echo -e "done.\n"
## refer2: http://stackoverflow.com/questions/1251999/sed-how-can-i-replace-a-newline-n
#jdktools=$(find $dirName/usr/lib/jvm/${java}1.${version}.0_${release}/bin/ -executable | awk -F/ '{print $7}' | sed ':a;N;$!ba;s/\n/ /g'
jdktools=$(find $dirName/usr/lib/jvm/$dataDir/bin/ -executable | awk -F/ '{print $7}' | sed ':a;N;$!ba;s/\n/ /g')
echo -n "${bold}Phase2: preparing required files...${normal}"

####################
## DEBIAN/control ## 
####################
cat << END > $dirName/DEBIAN/control
Package: oracle-${java}${version}
Version: 1.${version}u${release}
Architecture: $arch
Maintainer: Oracle
Depends: libc6 (>= 2.2.5)
Recommends: libxt-dev
Section: java
Priority: optional
Multi-Arch: same
Homepage: http://www.oracle.com/
END
if [ "$java" == "jdk" ]; then
cat << END >> $dirName/DEBIAN/control
Provides: java-compiler, java-sdk, java2-sdk, java5-sdk, java6-sdk, java7-jdk, java-runtime, java2-runtime, java5-runtime, java6-runtime, java7-runtime
Replaces: oracle-jre${version}, oracle-server-jre${version}
Description: Java SE Development Kit(JDK)
 For Java Developers. Includes a complete JRE plus tools for developing, debugging, and monitoring Java applications.
END
elif [ "$java" == "jre" ]; then
cat << END >> $dirName/DEBIAN/control
Conflicts: oracle-jdk${version}, oracle-server-jre${version}
Provides: java-runtime, java2-runtime, java5-runtime, java6-runtime, java7-runtime
Description: Java Runtime Environment(JRE)
 Covers most end-users needs. Contains everything required to run Java applications on your system.
END
else
cat << END >> $dirName/DEBIAN/control
Conflicts: oracle-jdk${version}, oracle-jre${version}
Provides: java-runtime, java2-runtime, java5-runtime, java6-runtime, java7-runtime
Description: Server Java Runtime Environment(Server JRE)
 For deploying Java applications on servers. Includes tools for JVM monitoring and tools commonly required for server applications, but does not include browser integration (the Java plug-in), auto-update, nor an installer.
END
fi
echo -n "25%..."


#####################
## DEBIAN/postinst ## 
#####################
cat << END > $dirName/DEBIAN/postinst
#!/bin/sh

set -e
multiarch=$multiarch
priority=$priority
basedir=/usr/lib/jvm/$dataDir
mandir=\$basedir/man
jdiralias=oracle-1.$version.0-$java-$arch
srcext=1.gz
dstext=1.gz
jdk_tools='$jdktools'

case "\$1" in
configure)
    # obsolete tool
    if update-alternatives --list apt 2>/dev/null; then
	update-alternatives --remove-all apt || true
    fi

    if [ -z "\$2" ]; then
	update_alternatives=y
    fi
    if [ -n "\$multiarch" ] && [ -n "\$2" ]; then
	for i in \$jdk_tools; do
	    if [ -z "\$(update-alternatives --list \$i 2>/dev/null | grep ^\$basedir/)" ]; then
		update_alternatives=y
		break
	    fi
	done
    fi
    if [ "\$update_alternatives" != y ] && [ \$priority -gt 1060 ]; then
	for i in \$jre_tools; do
	    oldp=\$(update-alternatives --query java | awk -v b=\$basedir '/^Alternative:/ && \$2~b {p=1} /^Priority:/ && p {print \$2; exit}')
	    if [ -n "\$oldp" ] && [ "\$oldp" -le 1060 ]; then
		update_alternatives=y
		break
	    fi
	done
    fi

    if [ "\$update_alternatives" = y ]; then
    if [ -n "\$multiarch" ] && [ "\$DPKG_MAINTSCRIPT_ARCH" != \$(dpkg --print-architecture) ]; then
	priority=\$(expr \$priority - 1)
    fi
    for i in \$jdk_tools; do
	unset slave1 slave2 || true
        if [ -e \$mandir/man1/\$i.\$srcext ]; then
	    slave1="--slave \
		/usr/share/man/man1/\$i.\$dstext \
                \$i.\$dstext \
                \$mandir/man1/\$i.\$srcext"
	fi
        if false && [ -e \$mandir/ja/man1/\$i.\$srcext ]; then
	    slave2="--slave \
		/usr/share/man/ja/man1/\$i.\$dstext \
                \${i}_ja.\$dstext \
                \$mandir/ja/man1/\$i.\$srcext"
	fi
        update-alternatives \
            --install \
            /usr/bin/\$i \
            \$i \
            \$basedir/bin/\$i \
            \$priority \
	    \$slave1 \$slave2
    done
    fi # update alternatives

    ;;
esac
##check folders for chrome and firefox      ####
[ -d "/opt/google/chrome" ] && {
	mkdir -p /opt/google/chrome/plugins
	ln -sf \$basedir/jre/lib/$arch/libnpjp2.so /opt/google/chrome/plugins/ 2>/dev/null
}
[ ! -d "/usr/lib/mozilla/plugins" ] && {
	mkdir -p /usr/lib/mozilla/plugins
	ln -sf \$basedir/jre/lib/$arch/libnpjp2.so /usr/lib/mozilla/plugins 2>/dev/null
}
##check folders for chrome and firefox done.####
echo 'export JAVA_HOME=\$(dirname \$(dirname \$(readlink -e \$(which java))))' >> /etc/profile


exit 0
END
echo -n "50%..."


#####################
## DEBIAN/preinst  ## 
#####################
##安裝前檢查若為安裝或升級相同版本，則先移除之。
cat << END > $dirName/DEBIAN/preinst
#!/bin/sh

set -e

old_basedir=/usr/lib/jvm/$dataDir
jdk_tools='$jdktools'
case "\$1" in
    upgrade)
	if [ -n "\$multiarch" ] && [ -n "\$2" ]; then
	    for i in \$jdk_tools; do
		if [ -n "\$(update-alternatives --list \$i 2>/dev/null | grep ^\$old_basedir/)" ]; then
		    update-alternatives --remove \$i \$old_basedir/bin/\$i || true
		fi
	    done
	fi
	;;
esac

exit 0
END
echo -n "75%..."


#####################
## DEBIAN/prerm    ## 
#####################
cat << END > $dirName/DEBIAN/prerm
#!/bin/sh -e

set -e

basedir=/usr/lib/jvm/$dataDir
jdk_tools='$jdktools'

if [ "\$1" = "remove" ] || [ "\$1" = "deconfigure" ]; then
    for i in \$jdk_tools; do
	update-alternatives --remove \$i \$basedir/bin/\$i
    done
fi
sed -i '/JAVA_HOME/d' /etc/profile
[ -h "/opt/google/chrome/plugins/libnpjp2.so" ] && { rm -f /opt/google/chrome/plugins/libnpjp2.so; }
[ -h "/usr/lib/mozilla/plugins" ] && { rm -f /usr/lib/mozilla/plugins/libnpjp2.so; }

exit 0
END
echo -e "100%.\n"

chmod +x $dirName/DEBIAN/*

echo  "${bold}Phase3: making ${dirName}.deb,${normal} this may take a long whilst... "
sudo dpkg-deb --build $dirName > /dev/null 
[ $? -eq 0 ] || { echo "exit"; exit 2; }
sudo chown $(id -un):$(id -gn) $dirName.deb
sudo rm -r $dirName

echo "${bold}$dirName.deb ${normal}has been done."

exit 0
