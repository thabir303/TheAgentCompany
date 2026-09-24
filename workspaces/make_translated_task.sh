#!/bin/bash
# Create a translated (e.g. Bangla) variant of a task and build its image locally.
#
# Step 1 - prepare:  bash workspaces/make_translated_task.sh <task-name>
#   Copies workspaces/tasks/<task-name> to workspaces/tasks_<lang>/<task-name>
#   and keeps the original instruction as task.en.md.
#   Now write the translation to task.<lang>.md in that directory (and, for
#   NPC tasks, optionally scenarios.<lang>.json).
#
# Step 2 - build:    bash workspaces/make_translated_task.sh <task-name>
#   Once task.<lang>.md exists, it becomes task.md (the file copied to
#   /instruction/task.md) and the image is built as
#   <prefix>/<task-name>-image:1.0.0, which run_eval.sh can use with
#   --image-prefix <prefix>.
#
# Environment variables:
#   LANG_CODE     language suffix of the translated files (default: bn)
#   IMAGE_PREFIX  image name prefix (default: tac-$LANG_CODE)
#
# Only translate natural-language text. Keep URLs, file names, paths, user
# names and required output formats unchanged: evaluators check them literally.
set -e

if [ -z "$1" ]; then
    echo "Usage: bash $0 <task-name>"
    exit 1
fi

TASK_NAME="$1"
LANG_CODE="${LANG_CODE:-bn}"
IMAGE_PREFIX="${IMAGE_PREFIX:-tac-$LANG_CODE}"
VERSION="1.0.0"

WORKSPACES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$WORKSPACES_DIR/tasks/$TASK_NAME"
DST_DIR="$WORKSPACES_DIR/tasks_$LANG_CODE/$TASK_NAME"

if [ ! -d "$SRC_DIR" ]; then
    echo "Error: task not found: $SRC_DIR"
    exit 1
fi

if [ ! -d "$DST_DIR" ]; then
    mkdir -p "$(dirname "$DST_DIR")"
    cp -r "$SRC_DIR" "$DST_DIR"
    cp "$DST_DIR/task.md" "$DST_DIR/task.en.md"
    if [ -f "$DST_DIR/scenarios.json" ]; then
        cp "$DST_DIR/scenarios.json" "$DST_DIR/scenarios.en.json"
    fi
    echo "Prepared $DST_DIR"
fi

if [ ! -f "$DST_DIR/task.$LANG_CODE.md" ]; then
    echo "Next: translate $DST_DIR/task.en.md into $DST_DIR/task.$LANG_CODE.md"
    if [ -f "$DST_DIR/scenarios.en.json" ]; then
        echo "(optional) translate NPC instructions into $DST_DIR/scenarios.$LANG_CODE.json"
    fi
    echo "Then run this script again to build the image."
    exit 0
fi

cp "$DST_DIR/task.$LANG_CODE.md" "$DST_DIR/task.md"
if [ -f "$DST_DIR/scenarios.$LANG_CODE.json" ]; then
    python3 -m json.tool "$DST_DIR/scenarios.$LANG_CODE.json" > /dev/null
    cp "$DST_DIR/scenarios.$LANG_CODE.json" "$DST_DIR/scenarios.json"
fi

IMAGE="$IMAGE_PREFIX/$TASK_NAME-image:$VERSION"
echo "Building $IMAGE ..."
docker build -t "$IMAGE" "$DST_DIR"
echo "Built $IMAGE"
echo "Run it with: bash run_eval.sh --image-prefix $IMAGE_PREFIX --task-list <file listing $TASK_NAME> --outputs-path outputs_$LANG_CODE ..."
