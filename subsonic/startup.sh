#!/usr/bin/env bash

function cleanup {
  kill `pidof tail` 2>/dev/null
  kill `pidof java` 2>/dev/null
}
trap cleanup EXIT
trap cleanup INT

cleanup

STATE_DIR=/opt/app/state

# Create the subsonic user using provided uid. 
SUBSONIC_UID=${1:-1000}
id ${SUBSONIC_UID} >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "INFO: Creating subsonic user with uid and gid: $SUBSONIC_UID"
  groupadd -g $SUBSONIC_UID subsonic
  useradd -g $SUBSONIC_UID -u $SUBSONIC_UID subsonic
fi

chown -R subsonic:subsonic /opt/app/state

# Copy the transcode binaries
if [[ ! -d ${STATE_DIR}/transcode ]]; then
  sudo -u subsonic mkdir -p ${STATE_DIR}/transcode
fi
echo "INFO: Copying transcode binaries to state dir"
sudo -u subsonic cp -Rf /opt/ffmpeg/* ${STATE_DIR}/transcode/

sudo -u subsonic /usr/bin/subsonic \
     --max-memory=${SUBSONIC_MAX_MEMORY:-512} \
     --home=${STATE_DIR} \
     --port=4040 \
     --default-music-folder=/mnt/music \
     --context-path=${SUBSONIC_CONTEXT_PATH:-/}

RES=$?
if [[ ! ${RES} -eq 0 ]]; then
  echo "ERROR: Exit code was ${RES}"
  exit 1
fi

TAIL_FILES="${STATE_DIR}/subsonic.log ${STATE_DIR}/subsonic_sh.log"

for WATCH_FILE in $TAIL_FILES; do
  while ! stat ${WATCH_FILE} >/dev/null 2>&1; do
    echo "Waiting for ${WATCH_FILE}"
    sleep 1
  done
done

tail -f $TAIL_FILES &

while kill -0 `pidof java` 2>/dev/null; do
  sleep 0.5
done