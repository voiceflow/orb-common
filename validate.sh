SRC_DIR=$(pwd)/src

# Flatten all the yaml files
for DIR in commands jobs executors; do
    # Copy all files in all subdirectories into orb-src
    find $SRC_DIR/$DIR -type f -exec cp {} $SRC_DIR/$DIR \; || :
done;

# Pack orb
circleci orb pack $SRC_DIR > "$SRC_DIR/orb.yml"

# Validate orb
circleci orb validate "$SRC_DIR/orb.yml"

# Clean all copied files
for DIR in commands jobs executors; do
    find $SRC_DIR/$DIR -type f -maxdepth 1  -name "*.yml" -exec rm -rf {} \; || :
done;