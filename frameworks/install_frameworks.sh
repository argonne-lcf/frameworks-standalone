#!/bin/bash

set -e

export SOURCE_DIR=$(realpath "$(dirname "$0")")
[[ "${DEBUG:-}" == *frameworks* ]] && echo "SOURCE_DIR=${SOURCE_DIR}"


COMPONENTS=(
    801-prep_install.sh
    #802-create_env.sh
    #803-frameworks_components.sh
    900-install_from_requirements.sh
    804-horovod.sh
    805-triton.sh
    #806-adorym.sh
    #807-plasma.sh
    808-list.sh
)

for i in "${COMPONENTS[@]}"; do
  echo "Applying $i"
  ${SOURCE_DIR}/$i
  [[ "${DEBUG:-}" == *frameworks* ]] && echo "Done Applying $i"
done

true

