
SRC_DIR=$(pwd)/src

# Flatten all the yaml files
for DIR in commands jobs executors examples; do
    # Copy all files in all subdirectories into orb-src
    find $SRC_DIR/$DIR -type f -exec cp {} $SRC_DIR/ \; || :
done;

# Pack orb
circleci orb pack --skip-update-check $SRC_DIR > "$SRC_DIR/orb.yml"

# Validate orb
circleci orb validate "$SRC_DIR/orb.yml"

# Do the cleanup
find $SRC_DIR -type f -maxdepth 1  -name "*.yml" ! -name "@orb.yml" -exec rm -rf {} \;