MakeJavaDeb
===========

Scripts to make an installable deb from a tarball downloaded from Oracle. 
The repo is aiming to make an installable deb. Format before and after transformed is like:

jdk-7u51-linux-x64.tar.gz       -- > oracle-jdk_1.7.0_51_amd64.deb

jre-8u5-linux-x64.tar.gz        -- > oracle-jre_1.8.0_5_amd64.deb

server-jre-8u5-linux-x64.tar.gz -- > oracle-server-jre_1.8.0_5_amd64.deb


Features
--------

  a) Accept Oracle JDK/JRE 1.7/1.8.

  b) Java 1.7 and 1.8 can be installed simultaniously. Use "update-alternatives" to switch within available version.

  c) No confliction with OpenJDK.

  d) Not compatiable for JDK/JRE 1.6 and earlier.
