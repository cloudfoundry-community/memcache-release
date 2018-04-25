build_java() {
  cd ${BOSH_COMPILE_TARGET}/$1
  cmd="./mvnw"

  cmd+=" -C -B -e install -Dmaven.test.skip";

  echo "Building $1: $cmd"
  eval $cmd

  cd -
}

set_default_java_home() {
  export JAVA_HOME=/var/vcap/packages/memcache-java
}

echo "Setting default JAVA_HOME"
set_default_java_home
