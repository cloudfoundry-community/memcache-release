set -e

echo "Checking git atleast 1.8"
if git --version | grep -q "1.8"; then
    echo "Git 1.8 found"
else
    echo "Git 1.8 not found"
    exit 1;
fi

echo "Checking for proxychains4 by download hitting Ruby Gems --head"
proxychains4 curl --head http://rubygems.org

echo "Making sure 'ruby' is on path."
type ruby

echo "Making sure 'bosh' is on path."
type bosh