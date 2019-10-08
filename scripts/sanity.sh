#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Metrics API open source project
##
## Copyright (c) 2018-2019 Apple Inc. and the Swift Metrics API project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftNIO open source project
##
## Copyright (c) 2017-2019 Apple Inc. and the SwiftNIO project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftNIO project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function replace_acceptable_years() {
    # this needs to replace all acceptable forms with 'YEARS'
    sed -e 's/2018-2019/YEARS/' -e 's/2019/YEARS/'
}

printf "=> Checking linux tests... "
FIRST_OUT="$(git status --porcelain)"
ruby "$here/../scripts/generate_linux_tests.rb" > /dev/null
SECOND_OUT="$(git status --porcelain)"
if [[ "$FIRST_OUT" != "$SECOND_OUT" ]]; then
  printf "\033[0;31mmissing changes!\033[0m\n"
  git --no-pager diff
  exit 1
else
  printf "\033[0;32mokay.\033[0m\n"
fi

printf "=> Checking format... "
FIRST_OUT="$(git status --porcelain)"
swiftformat --swiftversion 4.2 . > /dev/null 2>&1
SECOND_OUT="$(git status --porcelain)"
if [[ "$FIRST_OUT" != "$SECOND_OUT" ]]; then
  printf "\033[0;31mformatting issues!\033[0m\n"
  git --no-pager diff
  exit 1
else
  printf "\033[0;32mokay.\033[0m\n"
fi

printf "=> Checking license headers\n"
tmp=$(mktemp /tmp/.swift-metrics-sanity_XXXXXX)

for language in swift-or-c shell dtrace; do
  printf "   * %s... " "${language}"
  declare -a matching_files
  declare -a exceptions

  # We're setting a "dummy" value here so the variable properly expands, but does not cause any exceptions by default
  exceptions=( -name __FAKE_SANITY_PLACEHOLDER__ )

  matching_files=( -name '*' )
  case "$language" in
      swift-or-c)
        exceptions=( -name c_nio_http_parser.c -o -name c_nio_http_parser.h -o -name cpp_magic.h -o -name Package.swift -o -name CNIOSHA1.h -o -name c_nio_sha1.c -o -name ifaddrs-android.c -o -name ifaddrs-android.h)
        matching_files=( -name '*.swift' -o -name '*.c' -o -name '*.h' )
        cat > "$tmp" <<"EOF"
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) YEARS Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
EOF
        ;;
      shell)
        matching_files=( -name '*.sh' )
        cat > "$tmp" <<"EOF"
#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Metrics API open source project
##
## Copyright (c) YEARS Apple Inc. and the Swift Metrics API project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##
EOF
      ;;
      dtrace)
        matching_files=( -name '*.d' )
        cat > "$tmp" <<"EOF"
#!/usr/sbin/dtrace -q -s
/*===----------------------------------------------------------------------===*
 *
 *  This source file is part of the Swift Metrics API open source project
 *
 *  Copyright (c) YEARS Apple Inc. and the Swift Metrics API project authors
 *  Licensed under Apache License v2.0
 *
 *  See LICENSE.txt for license information
 *  See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
 *
 *  SPDX-License-Identifier: Apache-2.0
 *
 *===----------------------------------------------------------------------===*/
EOF
      ;;
    *)
      echo >&2 "ERROR: unknown language '${language}'"
      ;;
  esac

  expected_lines=$(wc -l < "${tmp}" )
  expected_sha=$(shasum < "${tmp}" )

  (
    cd "$here/.."
    find . \
      \( \! -path './.build/*' -a \
      \( "${matching_files[@]}" \) -a \
      \( \! \( "${exceptions[@]}" \) \) \) | while read -r line; do
      if [[ "$( replace_acceptable_years < "${line}" | head -n "${expected_lines}" | shasum)" != "$expected_sha" ]]; then
        printf "\033[0;31mmissing headers in file '%s'!\033[0m\n" "${line}"
        diff -u <( replace_acceptable_years < "${line}" | head -n "${expected_lines}" ) "$tmp"
        exit 1
      fi
    done
    printf "\033[0;32mokay.\033[0m\n"
  )
done

rm "$tmp"
