#!/bin/bash

CURR_DIR=`dirname $0`
if [ `uname -s` = Linux ] ; then
  if [ -z "$JENKINS_URL" ] ; then
    export JAVA_HOME=/usr/lib/jvm/java-9-oracle
  else
    export JAVA_HOME=/usr
  fi
else
  if [ `uname -s` = Darwin ] ; then
    export JAVA_HOME=`/usr/libexec/java_home -F -v1.9*`
  else
    export JAVA_HOME=/usr
  fi
fi

export PATH=$JAVA_HOME/bin:$PATH
JAVA=$JAVA_HOME/bin/java


# Most of these settings are fine for everyone
XSS=-Xss2m
XMX=-Xmx2048m
XX=
ENCODING=-Dfile.encoding=UTF-8
HEADLESS=-Djava.awt.headless=true
BOOT=xsbt.boot.Boot

SBT_LAUNCH=$HOME/.sbt/sbt-launch-0.13.8.jar
URL='http://repo.typesafe.com/typesafe/ivy-releases/org.scala-sbt/sbt-launch/0.13.8/sbt-launch.jar'

if [ ! -f $SBT_LAUNCH ] ; then
  echo "downloading" $URL
  mkdir -p $HOME/.sbt
  curl -s -S -L -f $URL -o $SBT_LAUNCH || exit
fi

if [ -z $JENKINS_URL ] ; then
  JAVA_OPTS="$XSS $XMX $XX"
else
  JAVA_OPTS="$XSS $XMX $XX -Dsbt.log.noformat=true"
fi

# Windows/Cygwin users need these settings
if [[ `uname -s` == *CYGWIN* ]] ; then

  # While you might want the max heap size lower, you'll run out
  # of heap space from running the tests if you don't crank it up
  # (namely, from TestChecksums)
  XMX=-Xmx2048m
  SBT_LAUNCH=`cygpath -w $SBT_LAUNCH`

fi

"$JAVA" \
    $JAVA_OPTS \
    $ENCODING \
    $HEADLESS \
    -classpath $SBT_LAUNCH \
    $BOOT "$@"
