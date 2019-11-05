#!/usr/bin/env bash

### BEGIN ###
# Author: lego users
# Since: 11:36:26 19/11/03
# Description:  function about pvm
# base          source ./py.sh
#
# Environment variables that control this script:
#
#   ██▓    ▓█████   ▄████  ▒█████
#  ▓██▒    ▓█   ▀  ██▒ ▀█▒▒██▒  ██▒
#  ▒██░    ▒███   ▒██░▄▄▄░▒██░  ██▒
#  ▒██░    ▒▓█  ▄ ░▓█  ██▓▒██   ██░
#  ░██████▒░▒████▒░▒▓███▀▒░ ████▓▒░
#  ░ ▒░▓  ░░░ ▒░ ░ ░▒   ▒ ░ ▒░▒░▒░
#  ░ ░ ▒  ░ ░ ░  ░  ░   ░   ░ ▒ ▒░
#    ░ ░      ░   ░ ░   ░ ░ ░ ░ ▒
#      ░  ░   ░  ░      ░     ░ ░
#
### END ###

set -e

LEGO_ROOT=$(dirname $(cd $(dirname "$0") && pwd -P)/$(basename "$0"))
COMMON_LEGO_ROOT=${LEGO_ROOT}/lego/legoes
MODULE_ROOT=${LEGO_ROOT}/pvm
SRCS_ROOT=${MODULE_ROOT}/srcs/py
LEGO_PROF_DIR=${LRD:-"/tmp/lego_prof"}
[ ! -d "${LEGO_PROF_DIR}" ] && mkdir -p "${LEGO_PROF_DIR}"

VENV_ROOT=${VR:-"${HOME}/.venvs"}

function _pvm_py_venv_must_have_venv_name() {
    local venv_name="${1}"
    if [[ -z ${venv_name} ]]; then
        echo "the virtualenv name must be given." >&2
        return 1
    else
        return 0
    fi
}

# init a virtualenv with venv path and python executable file
function pvm::py::init_venv() {
    local venv_name="${1}"
    local py_version="${2:-3}"
    _pvm_py_venv_must_have_venv_name "${venv_name}" || return 1
    command -v virtualenv ||
        sudo "$(command -v pip3)" install virtualenv

    virtualenv "${VENV_ROOT}/${venv_name}" -p "$(command -v "python${py_version}")" \
        --system-site-packages
}

# list all avaliable virtualenv name
function pvm::py::list_venv() {
    ls -l "${VENV_ROOT}" | grep '^d' | awk '{print $9}'
}

# output a virtualenv activate command, should exec as "$()" in the parents shell
function pvm::py::using_venv() {
    local venv_name=${1}
    _pvm_py_venv_must_have_venv_name "${venv_name}" || return 1
    echo "source ${VENV_ROOT}/${venv_name}/bin/activate"
}

# choice to output a virtualenv activate command
function pvm::py::choice_venv() {
    local venv_num=1
    declare -A venv_arr

    for venv in $(ls -l "${VENV_ROOT}" | grep '^d' | awk '{print $9}'); do
        printf "%s) \t %s\n" "${venv_num}" "${venv}"
        venv_arr[${venv_num}]="${venv}"
        # m=$[ m + 1]
        # m=`expr $m + 1`
        # m=$(($m + 1))
        # let m=m+1
        venv_num=$((venv_num + 1))
    done
    while (true); do
        local choice=
        read -r choice </dev/tty
        if [[ ${choice} -gt ${venv_num} ]]; then
            echo "invalidate input."
        fi
        echo "source ${VENV_ROOT}/${venv_arr[$choice]}/bin/activate"
        return 0
    done
}

# exit a virtualenv, should exec as "$()" in the parents shell
function pvm::py::exit_venv() {
    echo "deactivate"
}

# install conda
function pvm::py::install_conda() {
    if [ $(uname) = 'Darwin' ]; then
        brew cask install anaconda
        conda init zsh
        return 0
    fi
    local conda_install_sh="https://repo.continuum.io/miniconda/Miniconda3-4.7.12-Linux-x86_64.sh"
    local install_sh="${SRCS_ROOT}/Miniconda3-4.7.12-Linux-x86_64.sh"
    [ ! -d "${SRCS_ROOT}" ] && mkdir -p "${SRCS_ROOT}"
    [ -f "${install_sh}" ] || curl "${conda_install_sh}" >"${install_sh}"
    chmod +x "${install_sh}"
    sudo "${install_sh}" -b -p /usr/local/anaconda3
    export PATH=/usr/local/anaconda3/bin:$PATH
    conda init zsh
}

# https://zhuanlan.zhihu.com/p/32925500
# conda remove --name py35 --all
# conda info -e    # 环境列表
# conda list
# conda list -n py35
# conda search numpy
# 安装、更新、删除 某个环境的某个包
# conda install -n py35 numpy
# conda update -n py35 numpy
# conda remove -n py35 numpy
# conda update anaconda
# conda update conda
# conda update python
# 添加国内镜像
# conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
# conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
# conda config --set show_channel_urls yes# conda new a venv with venv name and python version
function pvm::py::conda_new_venv() {
    local venv_name=${1}
    local python_version=${2}
    if [ -z "${venv_name}" ] || [ -z "${python_version}" ]; then
        echo "venv name and python version must be given."
        return 1
    fi
    command -v conda || pvm::py::install_conda
    conda create -y --name "${venv_name}" python="${python_version}"
}

# using pyflame with python 3.6.5
function pvm::py::flame() {
    # Unexpected ptrace(2) exception:
    # Failed to PTRACE_PEEKDATA (pid xxx, addr 0x561664ad25a8): Input/output error
    command -v conda || pvm::py::conda_new_venv "py36" "3.6.5"
    # conda activate "py36"
    command -v pyflame || conda install -y -c eklitzke pyflame
    pyflame "$@"
}

# using python -m cProfile as python
# usage: o pvm py::cprof xxx.py -args
# generate a cpu profile in /tmp/"$(basename "${1}")"
function pvm::py::cprof() {
    local date_prix=$(date +"%y-%m-%d%H-%M-%S")
    local cp_file=${LEGO_PROF_DIR}/"$(basename "${1}").cprof"
    local callgrind_file=${LEGO_PROF_DIR}/"callgrind.$(basename "${1}")"
    [ -f "${cp_file}" ] && mv "${cp_file}" \
        "${LEGO_PROF_DIR}/$(basename "${1}")-${date_prix}.cprof"
    [ -f "${callgrind_file}" ] && mv "${callgrind_file}" \
        "${LEGO_PROF_DIR}/callgrind.$(basename "${1}")-${date_prix}"
    python -m cProfile -o "${cp_file}" $@
    command -v pyprof2calltree || pip install pyprof2calltree
    # using qcachegrind on mac to view callgrind_file
    pyprof2calltree -i "${cp_file}" -o "${callgrind_file}"
    command -v snakeviz || pip install snakeviz
    snakeviz -s -H 0.0.0.0 ${LEGO_PROF_DIR}/"$(basename "${1}").cprof"
}

# using snakeviz to parse a cpu profile in /tmp/"$(basename "${1}")"
function pvm::py::cprof_v() {
    command -v snakeviz || pip install snakeviz
    snakeviz -s -H 0.0.0.0 ${LEGO_PROF_DIR}/"$(basename "${1}").cprof"
}

# start a python http server at root:$1 port:$2
function pvm::start::http_server() {
    local root="${1:-${LEGO_PROF_DIR}}"
    cd "${root}"
    local port="${2:-"9999"}"
    netstat -nat | grep -i 'listen' | grep "${port}"
    if [[ $? -eq 1 ]]; then
        nohup python -m http.server 9999 >/dev/null 2>&1 &
    else
        echo "there is a http server already running at ${port}"
        ps aux | grep python | grep http.server | awk '{print $2}' | xargs kill -9
        nohup python -m http.server 9999 >/dev/null 2>&1 &
    fi
    sleep 0.1
    printf 'successful start the http server at: \nhttp://0.0.0.0:%s\n' "${port}"
    cd - >/dev/null 2>&1
}

# usage: o pvm py::mprof xxx.py -args
# use python memory_profiler profile a python script
function pvm::py::mprof() {
    pvm::start::http_server "${LEGO_PROF_DIR}"
    local date_prix=$(date +"%y-%m-%d%H-%M-%S")
    local mp_file=
    mp_file=${LEGO_PROF_DIR}/"$(basename "${1}").mprof"
    local mp_png=
    mp_png=${LEGO_PROF_DIR}/"$(basename "${1}").mprof.png"
    [ -f "${mp_file}" ] && mv "${mp_file}" ${LEGO_PROF_DIR}/"$(basename "${1}")-${date_prix}.mprof"
    [ -f "${mp_png}" ] && mv "${mp_png}" ${LEGO_PROF_DIR}/"$(basename "${1}")-${date_prix}.mprof.png"
    command -v mprof || pip install -U memory_profiler matplotlib
    mprof run --include-children --multiprocess --output "${mp_file}" "$@"
    mprof plot "${mp_file}" --output "${mp_png}"
    printf "view the data at: %s/%s" "http://0.0.0.0:9999" "$(basename "${1}").mprof.png"
}

function _pvm_pycallgraph() {
    command -v pycallgraph || pip install pycallgraph
    pycallgraph graphviz -- "$@"
}
