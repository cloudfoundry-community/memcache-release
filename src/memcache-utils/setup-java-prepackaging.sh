cd ${BUILD_DIR}

cleanup_java() {
  cd ${BUILD_DIR}
  mkdir -p keep
  mv *.jar keep
  find . \! -wholename "./keep/*" \! -wholename "./keep" \! -wholename './pre_packaging' \! -wholename './packaging' -delete
  mv keep/* .
  rm -rf keep
  cd -
}

build_java() {
  cd ${BUILD_DIR}/$1
  if [[ $BOSH_SKIP_TESTS != false ]] || [[ $2 != true ]] ; then
    echo "building and skipping tests for: $1"
    ./mvnw -B -e clean install -Dmaven.test.skip
  else
    echo "building and running tests for: $1"
    ./mvnw -B -e clean install
  fi
  cd -
}

case "$(uname)" in
	("Linux")
	    mkdir -p java
		tar zxf ${BUILD_DIR}/java/openjdk*.tar.gz -C java/
		
		export JAVA_HOME=${BUILD_DIR}/java

		;;
	("Darwin")
		export JAVA_HOME=$(/usr/libexec/java_home -v $JAVA_VERSION)

		;;
esac
