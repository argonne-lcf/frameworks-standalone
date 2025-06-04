#!/bin/bash
#

set -e

export CONDA_ENV_NAME=conda_python_3.11

export SOURCE_DIR=$(realpath "$(dirname "$0")")
[[ "${DEBUG:-}" == *frameworks* ]] && echo "SOURCE_DIR=${SOURCE_DIR}"


COMPONENTS=(
    101-prep_install.sh
    102-create_env.sh
    #200-install_from_requirements.sh
    #104-horovod.sh
    #105-triton.sh
    106-list.sh
)

for i in "${COMPONENTS[@]}"; do
  echo "Applying $i"
  echo ${SOURCE_DIR}
  ${SOURCE_DIR}/$i
  [[ "${DEBUG:-}" == *frameworks* ]] && echo "Done Applying $i"
done

true

