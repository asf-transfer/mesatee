#!/bin/bash
set -e
REQUIRED_ENVS=("MESATEE_PROJECT_ROOT" "MESATEE_OUT_DIR" "MESATEE_TARGET_DIR")
for var in "${REQUIRED_ENVS[@]}"; do
    [ -z "${!var}" ] && echo "Please set ${var}" && exit -1
done

LCOV=lcov
LCOVOPT="--gcov-tool ${MESATEE_PROJECT_ROOT}/cmake/scripts/llvm-gcov"
LCOV_REALPATH="${MESATEE_PROJECT_ROOT}/cmake/scripts/lcov_realpath.py"
GENHTML=genhtml

cd ${MESATEE_PROJECT_ROOT}
find . \( -name "*.gcda" -and \( ! -name "teaclave*" \
     -and ! -name "sgx_cov*" \
     -and ! -name "rusty_leveldb*" \
     -and ! -name "sgx_tprotected_fs*" \
     -and ! -name "protected_fs*" \) \) -exec rm {} \;
cd ${MESATEE_PROJECT_ROOT} && \
    for tag in `find ${MESATEE_PROJECT_ROOT} -name sgx_cov*.gcda | cut -d'.' -f2`; \
    do mkdir -p ${MESATEE_OUT_DIR}/cov_$tag && \
    find ${MESATEE_TARGET_DIR} -name *$tag* -exec cp {} ${MESATEE_OUT_DIR}/cov_$tag/ \; ; \
    ${LCOV} ${LCOVOPT} --capture \
    --directory ${MESATEE_OUT_DIR}/cov_$tag/ --base-directory . \
    -o ${MESATEE_OUT_DIR}/modules_$tag.info; done 2>/dev/null
rm -rf ${MESATEE_OUT_DIR}/cov_*
cd ${MESATEE_PROJECT_ROOT} && ${LCOV} ${LCOVOPT} --capture \
    --directory . --base-directory . \
    -o ${MESATEE_OUT_DIR}/modules.info 2>/dev/null
cd ${MESATEE_OUT_DIR} && ${LCOV} ${LCOVOPT} $(for tag in \
    `find ${MESATEE_PROJECT_ROOT} -name sgx_cov*.gcda | cut -d'.' -f2`; \
    do echo "--add modules_$tag.info"; done) \
    --add modules.info -o merged.info
cd ${MESATEE_OUT_DIR} && python ${LCOV_REALPATH} merged.info > merged_realpath.info
${LCOV} ${LCOVOPT} --extract ${MESATEE_OUT_DIR}/merged_realpath.info \
    `find ${MESATEE_PROJECT_ROOT} -path ${MESATEE_PROJECT_ROOT}/third_party -prune -o \
    -path ${MESATEE_PROJECT_ROOT}/build -prune -o \
    -path ${MESATEE_PROJECT_ROOT}/tests -prune -o \
    -name "*.rs"` -o cov.info
${GENHTML} --branch-coverage --demangle-cpp --legend cov.info \
    -o cov_report --ignore-errors source
