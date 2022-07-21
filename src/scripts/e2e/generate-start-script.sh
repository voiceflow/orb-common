#!/bin/bash

cat > ./start_e2e.sh \<< \EOF
#! /bin/bash

set -e

yarn gen-certs:e2e
yarn e2e

EOF

chmod +x ./start_e2e.sh