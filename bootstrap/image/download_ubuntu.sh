#!/bin/bash -e

# This script downloads an ubuntu image for KVM and creates an image template
# for it, which can be used later in the onebootstrap script.

REALPATH=$(readlink -f $0)
cd `dirname $REALPATH`

ID=4fc76a938fb81d3517000001
NAME="ubuntu-server-12.04"

URL="https://marketplace.c12g.com/appliance/$ID/download"

curl -sLk $URL | bunzip2 -c > $NAME.img

cat <<EOF > $NAME.image
NAME          = "$NAME"
PATH          = $(pwd)/$NAME.img
PUBLIC        = YES
EOF
