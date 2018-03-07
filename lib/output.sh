#!/usr/bin/env bash
# Private functions
__lib::output::cursor-right-by()  {
  lib::output::is_terminal && printf "\e[${1}C"
}

__lib::output::cursor-left-by()  {
  lib::output::is_terminal && printf "\e[${1}D"
}

__lib::output::cursor-up-by()  {
  lib::output::is_terminal && printf "\e[${1}A"
}

__lib::output::cursor-down-by()  {
  lib::output::is_terminal && printf "\e[${1}B"
}

__lib::output::cursor-move-to-y() {
  lib::output::is_terminal || return
  __lib::output::cursor-up-by 1000
  __lib::output::cursor-down-by ${1:-0}
}

__lib::output::cursor-move-to-x() {
  lib::output::is_terminal || return
  __lib::output::cursor-left-by 1000
  __lib::output::cursor-right-by ${1:-0}
}

__lib::ver-to-i() {
  version=${1}
  echo ${version} | awk 'BEGIN{FS="."}{ printf "1%02d%03.3d%03.3d", $1, $2, $3}'
}

lib::output::color::on() {
  printf "${bldcyn}"
  printf "${bldpur}" >&2
}

lib::output::color::off() {
  printf "${clr}"
  printf "${clr}" >&2
}

__lib::output::screen-width() {
  if [[ -n "${HomebaseCurrentScreenWidth}" &&
        $(( $(millis) - ${HomebaseCurrentScreenMillis} )) -lt 20000 ]]; then
    printf -- "${HomebaseCurrentScreenWidth}"
    return
  fi

  if [[ ${HomebaseCurrentOS:-$(uname -s)} == 'Darwin' ]]; then
    w=$(stty -a | grep columns | awk '{print $6}')
  elif [[ ${HomebaseCurrentOS} == 'Linux' ]]; then
    w=$(stty -a | grep columns | awk '{print $7}' | sed 's/;//g')
  fi

  MIN_WIDTH=${MIN_WIDTH:-70}
  w=${w:-${MIN_WIDTH}}
  [[ "${w}" -lt "${MIN_WIDTH}" ]] && w=${MIN_WIDTH}

  export HomebaseCurrentScreenWidth=${w}
  export HomebaseCurrentScreenMillis=$(millis)

  printf -- ${w}
}

__lib::output::screen-height() {
  if [[ ${HomebaseCurrentOS:-$(uname -s)} == 'Darwin' ]]; then
    h=$(stty -a | grep rows | awk '{print $4}')
  elif [[ ${HomebaseCurrentOS} == 'Linux' ]]; then
    h=$(stty -a | grep rows | awk '{print $5}' | sed 's/;//g')
  fi

  MIN_HEIGHT=${MIN_HEIGHT:-30}
  h=${h:-${MIN_HEIGHT}}
  [[ "${h}" -lt "${MIN_HEIGHT}" ]] && h=${MIN_HEIGHT}
  printf -- $(( $h - 2 ))
}

__lib::output::line() {
  __lib::output::repeat-char "─" $(( $(__lib::output::screen-width) - 2 ))
}

__lib::output::hr()  {
  local cols=${1:-$(__lib::output::screen-width)}
  local char=${2:-"—"}
  local color=${3:-${txtylw}}

  printf "${color}"
  __lib::output::repeat-char "─"
  printf "${clr}\n"
}

__lib::output::sep() {
  __lib::output::hr
  printf "\n"
}

__lib::output::repeat-char() {
  local screen_width=$(( $(__lib::output::screen-width) ))

  local char=${1:0:1}
  local width=${2:-${screen_width}}

  char=${char:-" "}
  for i in {0..1000}; do
    [[ $i -ge ${width} ]] && break
    printf "$char"
  done
}

# set background color to something before calling this
__lib::output::bar() {
  __lib::output::repeat-char " "
  printf "${clr}\n"
}

__lib::output::box-separator() {
  printf "├"
  __lib::output::line
  __lib::output::cursor-left-by 1
  printf "┤${clr}\n"
}

__lib::output::box-top() {
  printf "┌"
  __lib::output::line
  __lib::output::cursor-left-by 1
  printf "┐${clr}\n"
}

__lib::output::box-bottom() {
  printf "└"
  __lib::output::line
  __lib::output::cursor-left-by 1
  printf "┘${clr}\n"
}

__lib::output::clean() {
  local text="$*"
  printf -- "$text" | ruby -npe 'gsub(/\e\[[;m\d]+/, "")'
}

__lib::output::boxed-text() {
  local border_color=${1}
  shift
  local text_color=${1}
  shift
  local text="$*"

  [[ lib::output::is_terminal ]] || {
    printf ">>> %80.80s <<< \n" ${text}
    return
  }

  local clean_text=$(__lib::output::clean "${text}")
  local width=$(__lib::output::screen-width)
  local remaining_space_len=$(($width - ${#clean_text} - 3))
  printf "${border_color}│ ${text_color}${text}"
  [[ ${remaining_space_len} -gt 1 ]] && __lib::output::repeat-char " " ${remaining_space_len}
  __lib::output::cursor-left-by 1
  printf "${border_color}│${clr}\n"
}

#
# Usage: __lib::output::box border-color text-color "line 1" "line 2" ....
#
__lib::output::box() {
  local border_color=${1}
  shift
  local text_color=${1}
  shift

  [[ lib::output::is_terminal ]] || {
    for line in "$@"; do
      printf ">>> %80.80s <<< \n" ${line}
    done
    return
  }

  [[ -n "${opts_suppress_headers}" ]] && return

  printf "\n${border_color}"
  __lib::output::box-top

  local __i=0
  for line in "$@"; do
    [[ $__i == 1 ]] && {
      printf "${border_color}"
      __lib::output::box-separator
    }
    __lib::output::boxed-text "${border_color}" "${text_color}" "${line}"
    __i=$(( $__i + 1 ))
  done

  printf "${border_color}"
  __lib::output::box-bottom
  printf "${clr}"
}

__lib::output::center() {
  local color="${1}"
  shift
  local text="$*"

  local clean_text=$(__lib::output::clean "${text}")
  local width=$(__lib::output::screen-width)
  local remaining_space_len=$(( 1 + ($width - ${#clean_text}) / 2 ))

  local offset=0
  [[ $(( ( ${width} - ${#clean_text} ) % 2 )) == 1 ]] && offset=1

  printf "${color}"
  cursor.at.x -1
  __lib::output::repeat-char " " ${remaining_space_len}
  printf "${text}"
  __lib::output::repeat-char " " $(( ${remaining_space_len} + ${offset} ))
  printf "${clr}\n"
  cursor.at.x -1
}

__lib::output::left-justify() {
  local color="${1}"
  shift
  local text="$*"
  echo
  printf "${color}"
  ( lib::output::is_terminal ) && {
    local width=$(( $(__lib::output::screen-width) / 2 ))
    [[ ${width} -lt 60 ]] && width="60"
    __lib::output::repeat-char " " ${width}
    cursor.at.x 2
    printf "« ${text} »"
    printf "${clr}\n\n"
  }

  ( lib::output::is_terminal ) || {
    printf "  « ${text} »"
    printf "  ${clr}\n\n"
  }

}

################################################################################
# Public functions
################################################################################

# Prints text centered on the screen
# Usage: center "colors/prefix" "text"
#    eg: center "${bakred}${txtwht}" "Welcome Friends!"
center() {
  __lib::output::center "$@"
}

left() {
  __lib::output::left-justify "$@"
}

cursor.at.x() {
  __lib::output::cursor-move-to-x "$@"
}

cursor.at.y() {
  __lib::output::cursor-move-to-y "$@"
}

screen.width() {
  __lib::output::screen-width
}

screen.height() {
  __lib::output::screen-height
}

lib::output::is_terminal() {
   lib::output::is_tty || lib::output::is_redirect || lib::output::is_pipe
}

lib::output::is_tty() {
  [[ -t 1 ]]
}

lib::output::is_pipe() {
  [[ -p /dev/stdout ]]
}

lib::output::is_redirect() {
  [[ ! -t 1 && ! -p /dev/stdout ]]
}

box::yellow-in-red() {
  __lib::output::box "${bldred}" "${bldylw}" "$@"
}

box::blue-in-yellow() {
  __lib::output::box "${bldylw}" "${bldblu}" "$@"
}

box::blue-in-green() {
  __lib::output::box "${bldblu}" "${bldgrn}" "$@"
}

box::yellow-in-blue() {
  __lib::output::box "${bldylw}" "${bldblu}" "$@"
}

box::red-in-yellow() {
  __lib::output::box "${bldred}" "${bldylw}" "$@"
}

box::red-in-red() {
  __lib::output::box "${bldred}" "${txtred}" "$@"
}

box::green-in-magenta() {
  __lib::output::box "${bldgrn}" "${bldpur}" "$@"
}

box::magenta-in-green() {
  __lib::output::box "${bldpur}" "${bldgrn}" "$@"
}

box::magenta-in-blue() {
  __lib::output::box "${bldblu}" "${bldpur}" "$@"
}

hl::blue() {
  left "${bldwht}${bakblu}" "$@"
}

hl::green() {
  left "${txtblk}${bakgrn}" "$@"
}

hl::yellow() {
  left "${txtblk}${bakylw}" "$@"
}

hl::subtle() {
  left "${bldcyn}${bakblk}${underlined}" "$@"
}

hl::desc() {
  left "${txtblk}${bakylw}" "$@"
}

h::yellow() {
  center "${txtblk}${bakylw}" "$@"
}

h::red() {
  center "${txtwht}${bakred}" "$@"
}

h::green() {
  center "${txtblk}${bakgrn}" "$@"
}

h::blue() {
  center "${txtblk}${bakblu}" "$@"
}

h::black() {
  center "${bldylw}${bakblk}" "$@"
}

h1::green() {
  box::green-in-magenta "$@"
}

h1::purple() {
  box::magenta-in-green "$@"
}

h1::blue() {
  box::magenta-in-blue "$@"
}

h1::red() {
  box::red-in-red "$@"
}

h1::yellow() {
  box::yellow-in-red "$@"
}

h1() {
  box::blue-in-yellow "$@"
}

h2() {
  box::blue-in-green "$@"
}

hdr() {
  h1 "$@"
}

hr::colored() {
  local color=${1:-"red"}
  __lib::output::hr $(__lib::output::screen-width) "—" ${color}
}

function hr() {
  [[ -z "$*" ]] || printf $*
  __lib::output::hr
}

stdout() {
  local file=$1
  printf "\n${txtgrn}"
  [[ -s ${file} ]] && cat ${file}
  [[ -n ${file} ]] && printf "${clr}\n"
}

stderr() {
  local file=$1
  printf "\n${txtred}"
  [[ -s ${file} ]] && cat ${file}
  [[ -n ${file} ]] && printf "${clr}\n"
}

duration() {
  local millis=$1
  [[ -n $(which bc) ]] || return
  if [[ -n $millis && $millis -gt 0 ]] ; then
    cursor.at.x 1
    printf "${bldblu}%6.1fs " $(echo "scale=1;${millis}/1000" | bc)
  fi
}

ok() {
  __lib::output::cursor-left-by 1000
  printf "${bldgrn}✔︎${clr}"
}

not_ok() {
  __lib::output::cursor-left-by 1000
  printf "${bldred}✖${clr}"
}

kind_of_ok() {
  __lib::output::cursor-left-by 1000
  printf "${bldylw}⚠${clr}"
}

ok:() {
  ok $@
  echo
}

not_ok:() {
  not_ok $@
  echo
}

kind_of_ok:() {
  kind_of_ok $@
  echo
}

puts() {
  printf "  ⇨ ${txtwht}$*${clr}"
}

err() {
  printf -- "    ${bldwht}${bakred}ERROR:${clr} ${bldred}$*${clr}"
}

inf() {
  printf -- "    ${txtblu}${clr}${txtblu}$*${clr}"
}

warn() {
  printf -- "    ${txtblk}${bakylw} WARN:${clr} ${bldylw}$*${clr}"
}

info() {
  inf $@
  echo
}

error() {
  header=$(printf "${clr}${bakred}${bldwht}       « ERROR »       ${clr}")
  box::red-in-red "${header}" "$@"
  echo
}

warning() {
  warn $@
  echo
}

info:() {
  inf $*
  ok:
}

error:() {
  err $*
  not_ok:
}

warning:() {
  warn $*
  kind_of_ok:
}

shutdown() {
  local message=${1:-"Shutting down..."}
  echo
  box::red-in-red "${message}"
  echo
  exit 1
}

unalias hr 2>/dev/null

set +e
