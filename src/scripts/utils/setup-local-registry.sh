#!/bin/bash

docker create -v /verdaccio/conf --name verdaccio-conf alpine:3.4 /bin/true
/bin/bash -c "docker cp $CONFIG verdaccio-conf:/verdaccio/conf"

docker run -it --name verdaccio --network host -e NPM_TOKEN=${NPM_TOKEN} --volumes-from verdaccio-conf verdaccio/verdaccio:5