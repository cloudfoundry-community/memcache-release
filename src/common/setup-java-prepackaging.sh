MAVEN_VERSION=apache-maven-3.3.1
JAVA_VERSION=jdk1.8.0_40
JAVA_TAR_BALL=jdk-8u40-linux-x64.tar.gz

cd ${BUILD_DIR}

tar zxf ${BUILD_DIR}/java/${JAVA_TAR_BALL}

export JAVA_HOME=${BUILD_DIR}/${JAVA_VERSION}

tar zxf ${BUILD_DIR}/java/${MAVEN_VERSION}-bin.tar.gz

export MAVEN_HOME=${BUILD_DIR}/${MAVEN_VERSION}
export PATH=${MAVEN_HOME}/bin:$PATH

cleanup_java() {
  rm -rf ${JAVA_HOME}
  rm -rf ${MAVEN_HOME}
  rm -rf ${BUILD_DIR}/java
  rm -rf ${BUILD_DIR}/target
  rm -rf ${BUILD_DIR}/common
}
