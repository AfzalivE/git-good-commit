#!/usr/bin/env bash

#
# git-good-commit(1) - Git hook to help you write good commit messages.
# Released under the MIT License.
#
# Version 0.1.0
#
# https://github.com/tommarshall/git-good-commit
#

COMMIT_MSG_FILE="$1"
COMMIT_MSG_LINES=
SKIP_DISPLAY_WARNINGS=0
WARNINGS=

RED=
YELLOW=
BLUE=
WHITE=
NC=

#
# Set colour variables if the output should be coloured.
#

set_colors() {
  local default_color=$(git config --get color.ui || echo 'auto')
  if [[ $default_color == 'always' ]] || [[ $default_color == 'auto' && -t 1 ]]; then
    RED='\033[1;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[1;34m'
    WHITE='\033[1;37m'
    NC='\033[0m' # No Color
  fi
}

#
# Output prompt help information.
#

prompt_help() {
  echo -e "${RED}$(cat <<-EOF
e - edit commit message
y - proceed with commit
n - abort commit
? - print help
EOF
)${NC}"
}

#
# Add a warning with <line_number> and <msg>.
#

add_warning() {
  local line_number=$1
  local warning=$2
  WARNINGS[$line_number]="${WARNINGS[$line_number]}$warning;"
}

#
# Output warnings.
#

display_warnings() {
  if [ $SKIP_DISPLAY_WARNINGS -eq 1 ]; then
    # if the warnings were skipped then they should be displayed next time
    SKIP_DISPLAY_WARNINGS=0
    return
  fi

  for i in "${!WARNINGS[@]}"; do
    printf "%-74s ${WHITE}%s${NC}\n" "${COMMIT_MSG_LINES[$(($i-1))]}" "[line ${i}]"
    IFS=';' read -ra WARNINGS_ARRAY <<< "${WARNINGS[$i]}"
    for ERROR in "${WARNINGS_ARRAY[@]}"; do
      echo -e " ${YELLOW}- ${ERROR}${NC}"
    done
  done
}

#
# Read the contents of the commit msg into an array of lines.
#

read_commit_msg() {
  # reset commit_msg_lines
  COMMIT_MSG_LINES=()

  # read commit message into lines array
  while IFS= read -r; do

    # trim trailing spaces from commit lines
    shopt -s extglob
    REPLY="${REPLY%%*( )}"
    shopt -u extglob

    # ignore comments
    [[ $REPLY =~ ^# ]]
    test $? -eq 0 || COMMIT_MSG_LINES+=("$REPLY")

  done < <(cat $COMMIT_MSG_FILE)
}

#
# Validate the contents of the commmit msg agains the good commit guidelines.
#

validate_commit_message() {
  # reset warnings
  WARNINGS=()

  # if the commit is empty there's nothing to validate, we can return here
  COMMIT_MSG_STR="${COMMIT_MSG_LINES[*]}"
  test -n "${COMMIT_MSG_STR[*]// }" || return;

  # 1. Separate subject from body with a blank line
  # ------------------------------------------------------------------------------

  test ${#COMMIT_MSG_LINES[@]} -lt 1 || test -z "${COMMIT_MSG_LINES[1]}"
  test $? -eq 0 || add_warning 2 "Separate subject from body with a blank line"

  # 2. Limit the subject line to 50 characters
  # ------------------------------------------------------------------------------

  test "${#COMMIT_MSG_LINES[0]}" -le 50
  test $? -eq 0 || add_warning 1 "Limit the subject line to 50 characters (${#COMMIT_MSG_LINES[0]} chars)"

  # 3. Capitalize the subject line
  # ------------------------------------------------------------------------------

  [[ ${COMMIT_MSG_LINES[0]} =~ ^[[:blank:]]*([[:upper:]]{1}[[:lower:]]*|[[:digit:]]+)([[:blank:]]|[[:punct:]]|$) ]]
  test $? -eq 0 || add_warning 1 "Capitalize the subject line"

  # 4. Do not end the subject line with a period
  # ------------------------------------------------------------------------------

  [[ ${COMMIT_MSG_LINES[0]} =~ [^\.]$ ]]
  test $? -eq 0 || add_warning 1 "Do not end the subject line with a period"

  # 5. Use the imperative mood in the subject line
  # ------------------------------------------------------------------------------

  IMPERATIVE_MOOD_BLACKLIST=(
    added          adds          adding
    avoided        avoids        avoiding
    amended        amends        amending
    bumped         bumps         bumping
    changed        changes       changing
    checked        checks        checking
    committed      commits       committing
    copied         copies        copying
    corrected      corrects      correcting
    created        creates       creating
    deleted        deletes       deleting
    fixed          fixes         fixing
    implemented    implements    implementing
    improved       improves      improving
    introduced     introduces    introducing
    moved          moves         moving
    pruned         prunes        pruning
    refactored     refactors     refactoring
    removed        removes       removing
    renamed        renames       renaming
    replaced       replaces      replacing
    resolved       resolves      resolving
    showed         shows         showing
    tested         tests         testing
    updated        updates       updating
    used           uses          using
  )

  # enable case insensitive match
  shopt -s nocasematch

  for BLACKLISTED_WORD in "${IMPERATIVE_MOOD_BLACKLIST[@]}"; do
    [[ ${COMMIT_MSG_LINES[0]} =~ $BLACKLISTED_WORD ]]
    test $? -eq 0 && add_warning 1 "Use the imperative mood in the subject line, e.g 'fix' not 'fixes'" && break
  done

  # disable case insensitive match
  shopt -u nocasematch

  # 6. Wrap the body at 72 characters
  # ------------------------------------------------------------------------------

  URL_REGEX='^[[:blank:]]*(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

  for i in "${!COMMIT_MSG_LINES[@]}"; do
    LINE_NUMBER=$((i+1))
    test "${#COMMIT_MSG_LINES[$i]}" -le 72 || [[ ${COMMIT_MSG_LINES[$i]} =~ $URL_REGEX ]]
    test $? -eq 0 || add_warning $LINE_NUMBER "Wrap the body at 72 characters (${#COMMIT_MSG_LINES[$i]} chars)"
  done

  # 7. Use the body to explain what and why vs. how
  # ------------------------------------------------------------------------------

  # ?

  # 8. Do no write single worded commits
  # ------------------------------------------------------------------------------

  COMMIT_SUBJECT_WORDS=(${COMMIT_MSG_LINES[0]})
  test "${#COMMIT_SUBJECT_WORDS[@]}" -gt 1
  test $? -eq 0 || add_warning 1 "Do no write single worded commits"

  # 9. Do not start the subject line with whitespace
  # ------------------------------------------------------------------------------

  [[ ${COMMIT_MSG_LINES[0]} =~ ^[[:blank:]]+ ]]
  test $? -eq 1 || add_warning 1 "Do not start the subject line with whitespace"
}

#
# It's showtime.
#

set_colors

if tty >/dev/null 2>&1; then
  TTY=$(tty)
else
  TTY=/dev/tty
fi

while true; do

  read_commit_msg

  validate_commit_message

  # if there are no WARNINGS are empty then we're good to break out of here
  test ${#WARNINGS[@]} -eq 0 && exit 0;

  display_warnings

  # Ask the question (not using "read -p" as it uses stderr not stdout)
  echo -en "${BLUE}Proceed with commit? [e/y/n/?] ${NC}"

  # Read the answer
  read REPLY < "$TTY"

  # Check if the reply is valid
  case "$REPLY" in
    E*|e*) $EDITOR "$COMMIT_MSG_FILE" < $TTY; continue ;;
    Y*|y*) exit 0 ;;
    N*|n*) exit 1 ;;
    *)     SKIP_DISPLAY_WARNINGS=1; prompt_help; continue ;;
  esac

done
