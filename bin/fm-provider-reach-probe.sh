#!/usr/bin/env bash
# fm-provider-reach-probe.sh - one hard-bounded reachability probe of a named
# model-provider endpoint: DNS resolution plus one unauthenticated HTTP request.
#
# This script collects a FACT and renders no verdict. It reads no dispatch
# configuration, holds no provider table, and never decides whether a candidate
# is eligible or which route to take. The dispatching first mate owns that
# judgment from `quota-axi`'s data plus each harness's authoritative model
# catalog (`.agents/skills/quota-array-dispatch/SKILL.md`).
#
# Why it exists: upstream outage was previously visible only by reading worker
# panes, so "the endpoint is down" was never a machine-readable condition at an
# intake. This turns that finding into one bounded call with a readable exit
# status. It is not a service, a daemon, a watcher, or a control plane: nothing
# registers it, it keeps no state, and it runs only when called.
#
# What it deliberately cannot prove: a 2xx establishes only that the endpoint is
# routable and answering. It is never evidence that a model is usable, that a
# credential works, or that a large or long-output request will succeed; this
# home has recorded outages where small requests returned 200 while large ones
# hung. Never record a 2xx as "channel available".
#
# Usage:
#   fm-provider-reach-probe.sh --host <host[:port][/path]> [options]
#
# The caller names the endpoint explicitly; the probe ships no provider endpoint
# of its own, and no built-in target, alias, or provider name exists to select
# one. That is an authorization boundary rather than a convenience trade: a
# built-in vendor host would make this tool decide on its own to send an
# unauthenticated request to one particular third party, whereas with an explicit
# host the destination, and the responsibility for it, stay with the caller.
# Nothing here reads, needs, or transmits a credential; a --host that carries
# userinfo is refused rather than sent.
#
# `--host` takes a hostname, an IPv4 literal, or an IPv6 literal in either form:
# bracketed with an optional port (`[2001:db8::1]:8443`), or a bare literal
# (`2001:db8::1`), which is bracketed for the request. A port on an IPv6 literal
# requires the bracketed form, because `2001:db8::1:8443` is itself a valid
# address. A path may follow either form.
#
# Entry in this tool's own history, kept because it is easy to repeat: the host
# in local use is `xhyapi.com`, without an `api.` prefix, and `api.xhyapi.com`
# answers NXDOMAIN permanently. A probe of the wrong name looked exactly like an
# upstream outage for several days. With no built-in target a naming mistake has
# to be written out in the --host the caller supplies, so it surfaces as an
# explicit configuration error instead of a silent default.
#
# Options:
#   --timeout <seconds>   same bound as FM_PROVIDER_REACH_PROBE_TIMEOUT and
#                         preferred over it; must be a positive integer
#   -h, --help            print this usage and exit 0
#
# Output: exactly one line on stdout. The probe label is hostname[:port] only;
# any supplied path is omitted. No token, key, header, or response body is ever
# printed or written to disk: the response body is discarded to /dev/null and
# only the HTTP status code is captured. The status code and DNS rcode are
# protocol facts, not secrets.
#
#   probe=<hostname[:port]> dns=<ok|nxdomain|unknown|skipped> http=<code|none> result=<verdict> <detail>
#
# result is evidence, never eligibility. Each verdict carries its own exit status:
#   reachable        0    HTTP 2xx: routable and answering, nothing more proven
#   routed-auth      10   HTTP 401 or 403: a request reached the endpoint and was
#                         refused, so routing works but usability is NOT proven
#   server-error     11   HTTP 5xx or any other code: answered, unhealthy or unknown
#   unreachable      20   connection failed, timeout, or no address: NXDOMAIN or any
#                         lookup errors print dns=unknown and HTTP is still
#                         attempted, so a DNS-tool problem cannot suppress the probe
#   invalid-target   2    --host yields no request authority at all, e.g. a path
#                         with no host part
#   invalid-input    2    missing --host, an unexpected argument, a non-numeric,
#                         zero, or negative --timeout value, duplicate options,
#                         a missing option value (a token starting with `-`
#                         counts as missing), an unusable --host authority
#                         (a port outside 1-65535 or written with a leading
#                         zero, a malformed IP literal, a bad bracket shape, a
#                         host name character outside letters/digits/dots/
#                         hyphens/underscores, whitespace, or a control
#                         character), or a credential-bearing proxy URL
#   tool-missing     64   curl is not installed: nothing was probed and the line
#                         says so rather than silently reporting another outcome
# Exit 2 is reserved for usage, host-configuration, and proxy-environment
# errors. A running probe always prints exactly one line on stdout, including
# tool-missing and invalid-target; invalid-input is the one error path that
# prints only on stderr.
#
# Environment:
#   FM_PROVIDER_REACH_PROBE_TIMEOUT   hard bound in seconds applied to each
#                                     resolver invocation and to the one HTTP
#                                     request. With N configured resolver
#                                     candidates the DNS phase can spend up to 2N
#                                     bounds - an A query and its AAAA fallback
#                                     for each - before the request spends one
#                                     more, so the whole run is bounded by 2N+1
#                                     bounds. Must be a positive integer, else the
#                                     default 10 is used. Zero is rejected because
#                                     `timeout 0` and the Perl fallback's
#                                     `alarm 0` both mean "no deadline".
#   FM_PROVIDER_REACH_DNS_TOOL        one resolver CLI, or a whitespace-separated
#                                     preference list tried in order until one that
#                                     is installed answers (default: /usr/bin/dig,
#                                     then /usr/bin/host). Each entry takes the
#                                     bare hostname and no other argument, so a
#                                     tool needs its own entry - and a token that
#                                     is not an installed tool is skipped, never
#                                     run. Tests use it to keep DNS deterministic.
#   FM_TEST_SEAM                      when 1, allow FM_PROVIDER_REACH_CURL_CMD to
#                                     name the curl executable, so a suite can
#                                     prove the curl-absent branch on a host whose
#                                     /usr/bin/curl cannot otherwise be hidden.
#                                     Unset outside a test suite, so a normal run
#                                     always uses this host's real curl.
set -u

DEFAULT_TIMEOUT=10
DNS_DEFAULT_CANDIDATES='/usr/bin/dig /usr/bin/host'

usage() {
  cat <<'EOF'
fm-provider-reach-probe.sh - one hard-bounded reachability probe of a named
model-provider endpoint: DNS resolution plus one unauthenticated HTTP request.
It collects a fact and renders no verdict: it reads no dispatch configuration,
holds no provider table, and never decides dispatch eligibility or routing.

Usage:
  fm-provider-reach-probe.sh --host <host[:port][/path]> [options]

The endpoint is named explicitly with --host; the probe ships no provider
endpoint of its own, and no built-in target, alias, or provider name selects one.
That is an authorization boundary, not a convenience gap: a built-in vendor host
would make this tool decide by itself to send an unauthenticated request to one
particular third party, while an explicit --host keeps the destination, and the
responsibility for it, with the caller. Nothing here reads, needs, or transmits a
credential; a --host carrying userinfo is refused rather than sent.

--host accepts:
  hostname[/path]            e.g. example.com/health
  hostname:port[/path]       e.g. example.com:8443/health
  IPv4 literal[/path]        e.g. 192.0.2.10/health
  [IPv6 literal][:port]      e.g. [2001:db8::1]:8443/health
  bare IPv6 literal[/path]   e.g. 2001:db8::1, bracketed for the request
A port on an IPv6 literal requires the bracketed form, because
2001:db8::1:8443 is itself a valid address.

Known naming pitfall, kept because it is easy to repeat: the host in local use
is xhyapi.com, with no api. prefix; api.xhyapi.com answers NXDOMAIN
permanently. Probing the wrong name once looked like an upstream outage for
days. With no built-in target that mistake has to appear in the --host the
caller writes, so it is an explicit configuration error rather than a default.

Example for the local endpoint, including its path:
  fm-provider-reach-probe.sh --host xhyapi.com/v1/models

Options:
  --timeout <seconds>   hard bound applied to each resolver invocation and to the
                        one HTTP request (positive integer, default 10): with N
                        configured resolver candidates the DNS phase can spend up
                        to 2N bounds (an A query plus its AAAA fallback each),
                        then the request spends one more; beats
                        FM_PROVIDER_REACH_PROBE_TIMEOUT
  -h, --help            show this help

Prints exactly one line on stdout; the probe label is hostname[:port] and
omits any supplied path:
  probe=<hostname[:port]> dns=<ok|nxdomain|unknown|skipped> http=<code|none> result=<verdict> <detail>

A 2xx proves routability only - never that a model, credential, or large request
works - so it is recorded as reachable, not as "channel available".
A 401 or 403 means a request reached the endpoint and was refused: routing works,
usability is not proven.
Only the HTTP status code is read; the response body is discarded to /dev/null.

Exit status (verdicts are not eligibility):
  0   reachable       HTTP 2xx
  10  routed-auth     HTTP 401/403
  11  server-error    HTTP 5xx or other code
  20  unreachable     connection failed, timed out, or no address (NXDOMAIN
                      exits before HTTP; resolver errors report dns=unknown and
                      continue to HTTP)
  2   invalid-target  --host carries no request authority at all (a path only)
  2   invalid-input   missing/unknown --host, an unexpected argument, a bad or
                      repeated --timeout, a missing option value (a token
                      starting with - counts as missing), an unusable --host
                      authority (a port outside 1-65535 or with a leading zero,
                      a malformed IP literal, a bad bracket shape, a host name
                      character outside letters/digits/dots/hyphens/underscores,
                      whitespace, or a control character), or a
                      credential-bearing proxy URL (stderr only)
  64  tool-missing    curl absent: nothing probed, one line on stdout
EOF
}

# One diagnostic line on stderr, then exit 2. Nothing goes to stdout, so a
# caller never reads a partial probe line for a probe that never ran.
die_input() {
  printf 'fm-provider-reach-probe: %s\n' "$1" >&2
  exit 2
}

HOST_ARG=''
TIMEOUT_ARG=''
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --host)
      case "${2:-}" in ''|-*) die_input "--host needs a value" ;; esac
      [ -z "$HOST_ARG" ] || die_input "only one --host may be given"
      HOST_ARG=$2; shift 2 ;;
    --timeout)
      case "${2:-}" in ''|-*) die_input "--timeout needs a value" ;; esac
      [ -z "$TIMEOUT_ARG" ] || die_input "only one --timeout may be given"
      TIMEOUT_ARG=$2; shift 2 ;;
    -*) die_input "unknown option" ;;
    *) die_input "unexpected argument" ;;
  esac
done
[ -n "$HOST_ARG" ] || die_input "--host <host[:port][/path]> is required"

# Positive integer or the default: `timeout 0` and the Perl fallback's `alarm 0`
# both disable the deadline, so a hung endpoint would otherwise run unbounded.
normalize_timeout() {
  case "$1" in
    ''|0|*[!0-9]*|0[0-9]*) return 1 ;;
  esac
  [ "${#1}" -le 9 ] || return 1
  [ "$1" -gt 0 ] || return 1
  return 0
}

TIMEOUT=${FM_PROVIDER_REACH_PROBE_TIMEOUT:-$DEFAULT_TIMEOUT}
normalize_timeout "$TIMEOUT" || TIMEOUT=$DEFAULT_TIMEOUT
if [ -n "$TIMEOUT_ARG" ]; then
  # An explicit --timeout is a contract violation, not a hint: refuse loudly
  # rather than quietly falling back to the default the caller did not ask for.
  normalize_timeout "$TIMEOUT_ARG" || die_input "--timeout must be a positive integer"
  TIMEOUT=$TIMEOUT_ARG
fi

# Curl honors proxy environment variables even with -q. Select only the HTTPS
# proxy applicable to this request. A proxy carrying userinfo is refused
# unconditionally as invalid input, in this early validation pass beside --host:
# no resolver answer, absent curl, or other early outcome may end the run first.
# NO_PROXY is not emulated, so no bypass entry can turn that refusal off and let
# a credential reach a proxy while the route says direct.
proxy_env_value() {
  local upper=$1 lower=$2 value
  eval 'value=${'"$lower"'-}'
  if [ -n "$value" ]; then printf '%s' "$value"; return; fi
  eval 'value=${'"$upper"'-}'
  printf '%s' "$value"
}
PROXY_MODE=direct
proxy_value=$(proxy_env_value HTTPS_PROXY https_proxy)
[ -n "$proxy_value" ] || proxy_value=$(proxy_env_value ALL_PROXY all_proxy)
if [ -n "$proxy_value" ]; then
  PROXY_MODE=via-proxy
  proxy_authority=${proxy_value#*://}
  proxy_authority=${proxy_authority%%[/?#]*}
  case "$proxy_authority" in
    *@*) die_input "proxy URL carries credentials: the probe never sends one" ;;
  esac
fi

# Bounded execution is owned by bin/fm-timeout-lib.sh, so a macOS host without
# coreutils still gets a hard bound instead of an unbounded endpoint call.
# shellcheck source=bin/fm-timeout-lib.sh
# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fm-timeout-lib.sh"

# An authority that cannot become a valid https authority is a caller error, so
# IP literals are validated by value, not only by shape: curl's own rejection of
# a bad address would otherwise be reported as an endpoint outage.
ipv4_literal_ok() {
  local rest=$1 dots o1 o2 o3 o4 octet
  case "$rest" in
    ''|*[!0-9.]*) return 1 ;;
  esac
  dots=${rest//[^.]/}
  [ "${#dots}" -eq 3 ] || return 1
  o1=${rest%%.*}; rest=${rest#*.}
  o2=${rest%%.*}; rest=${rest#*.}
  o3=${rest%%.*}; o4=${rest#*.}
  for octet in "$o1" "$o2" "$o3" "$o4"; do
    case "$octet" in
      ''|*[!0-9]*|0?*) return 1 ;;
    esac
    [ "${#octet}" -le 3 ] || return 1
    [ "$octet" -le 255 ] || return 1
  done
  return 0
}

# Sets LITERAL_GROUPS to the number of 16-bit groups $1 contributes to an IPv6
# address, or fails when a group is not 1-4 hex digits or a dotted quad is
# misplaced. $2 allows a trailing dotted quad, which is only legal after every
# hex group.
ipv6_side_groups() {
  local side=$1 allow_v4=$2 part i=0 count
  local -a groups=()
  LITERAL_GROUPS=0
  [ -n "$side" ] || return 0
  IFS=':' read -ra groups <<< "$side"
  count=${#groups[@]}
  while [ "$i" -lt "$count" ]; do
    part=${groups[$i]}
    case "$part" in
      *.*)
        [ "$allow_v4" = 1 ] && [ "$i" -eq $((count - 1)) ] || return 1
        ipv4_literal_ok "$part" || return 1
        LITERAL_GROUPS=$((LITERAL_GROUPS + 2))
        ;;
      *)
        case "$part" in
          ''|*[!0-9A-Fa-f]*) return 1 ;;
        esac
        [ "${#part}" -le 4 ] || return 1
        LITERAL_GROUPS=$((LITERAL_GROUPS + 1))
        ;;
    esac
    i=$((i + 1))
  done
  return 0
}

ipv6_literal_ok() {
  local addr=$1 left right left_groups
  case "$addr" in
    *::*)
      left=${addr%%::*}
      right=${addr#*::}
      case "$right" in *::*) return 1 ;; esac
      ipv6_side_groups "$left" 0 || return 1
      left_groups=$LITERAL_GROUPS
      ipv6_side_groups "$right" 1 || return 1
      [ $((left_groups + LITERAL_GROUPS)) -le 7 ] || return 1
      return 0
      ;;
  esac
  ipv6_side_groups "$addr" 1 || return 1
  [ "$LITERAL_GROUPS" -eq 8 ]
}

case "$HOST_ARG" in
  *\?*) die_input "query component is not supported" ;;
esac
# curl never sends a fragment, so accepting one would probe a different path than
# the caller wrote while the probe label omits the path entirely.
case "$HOST_ARG" in
  *'#'*) die_input "fragment component is not supported" ;;
esac
# A credential belongs to no probe: userinfo (`user:pass@host`) is refused before
# anything else looks at the value, so it can never be composed into a request or
# echoed back. The refusal names only the shape, never the supplied text.
case "$HOST_ARG" in
  *@*) die_input "--host must not carry credentials (userinfo): name the host only; the probe never sends one" ;;
esac
if [[ "$HOST_ARG" =~ ^[A-Za-z][A-Za-z0-9+.-]*:// ]]; then
  die_input "--host must be a host[:port][/path], not a URL"
fi
# Whitespace and control characters cannot appear unescaped in a request URL,
# and a space in the authority would also break the one-line probe framing.
case "$HOST_ARG" in
  *[[:space:][:cntrl:]]*) die_input "--host must not contain whitespace or control characters" ;;
esac

# Split the authority from any path, then normalize an IPv6 literal into the
# bracketed form a URL authority requires. A bare literal is what a resolver and
# the OS accept, so `--host 2001:db8::1` is a reasonable thing to type; building
# `https://2001:db8::1` from it would hand curl a malformed authority and report
# a connection failure for a target that was never actually requested.
HOST_PATH=''
case "$HOST_ARG" in
  */*) HOST_PATH=/${HOST_ARG#*/} ;;
esac
HOST_AUTH=${HOST_ARG%%/*}
# A port or bracket shape that cannot become a valid https authority is a caller
# error, never an endpoint finding: refusing it here keeps curl's own URL
# rejection from being reported as result=unreachable.
AUTH_PORT=''
AUTH_PORT_SET=0
case "$HOST_AUTH" in
  '['*)
    bracket_tail=${HOST_AUTH#\[}
    case "$bracket_tail" in
      *']'*) v6_literal=${bracket_tail%%\]*}; bracket_tail=${bracket_tail#*\]} ;;
      *) die_input "--host has an unterminated IPv6 bracket: write [address] or [address]:port" ;;
    esac
    ipv6_literal_ok "$v6_literal" || die_input "--host bracketed value is not an IPv6 literal"
    case "$bracket_tail" in
      '') ;;
      :*) AUTH_PORT_SET=1; AUTH_PORT=${bracket_tail#:} ;;
      *) die_input "--host has text after the IPv6 bracket: write [address] or [address]:port" ;;
    esac
    URL_AUTH="[$v6_literal]"
    ;;
  *)
    # Two or more colons cannot be host:port, so the value is an IPv6 literal.
    host_colons=${HOST_AUTH//[^:]/}
    if [ "${#host_colons}" -ge 2 ]; then
      ipv6_literal_ok "$HOST_AUTH" || die_input "--host has more than one colon but is not an IPv6 literal: bracket an IPv6 address or write one host:port"
      URL_AUTH="[$HOST_AUTH]"
    else
      case "$HOST_AUTH" in
        *:*) AUTH_PORT_SET=1; AUTH_PORT=${HOST_AUTH#*:}; HOST_ONLY=${HOST_AUTH%%:*} ;;
        *) HOST_ONLY=$HOST_AUTH ;;
      esac
      if [ "$AUTH_PORT_SET" = 1 ] && [ -z "$HOST_ONLY" ]; then
        die_input "--host must name a host before its port"
      fi
      case "$HOST_ONLY" in
        *[!A-Za-z0-9._-]*) die_input "--host name may contain only ASCII letters, digits, dots, hyphens, and underscores (or be a bracketed IPv6 literal)" ;;
      esac
      case "$HOST_ONLY" in
        ''|*[!0-9.]*) ;;
        *.*) ipv4_literal_ok "$HOST_ONLY" || die_input "--host dotted address must be four octets from 0 to 255" ;;
      esac
      URL_AUTH=$HOST_ONLY
    fi
    ;;
esac
if [ "$AUTH_PORT_SET" = 1 ]; then
  case "$AUTH_PORT" in
    ''|0*|*[!0-9]*) die_input "--host port must be a number from 1 to 65535" ;;
  esac
  [ "${#AUTH_PORT}" -le 5 ] || die_input "--host port must be a number from 1 to 65535"
  [ "$AUTH_PORT" -le 65535 ] || die_input "--host port must be a number from 1 to 65535"
  URL_AUTH="$URL_AUTH:$AUTH_PORT"
fi
BASE=https://$URL_AUTH$HOST_PATH

# A --host value with no host part cannot yield a request authority: that is a
# caller error, never a healthy probe, so it gets its own verdict before any
# resolver or request runs instead of letting curl invent a connection failure.
AUTHORITY=$(printf '%s\n' "$BASE" | sed -nE 's|^https?://([^/?#]+).*|\1|p')
PROBE=host:$AUTHORITY

# The resolver takes a bare DNS name, never a URL authority: a `:port` suffix and
# the brackets around an IPv6 literal are URL syntax, not part of the name to look
# up. Passing the authority verbatim asked the resolver for `host:port`, which it
# treats as a query name, so a perfectly reachable endpoint was recorded as
# NXDOMAIN before any request ran. The port survives in BASE for the request.
DNS_HOST=$AUTHORITY
case "$DNS_HOST" in
  \[*\]*) DNS_HOST=${DNS_HOST#\[}; DNS_HOST=${DNS_HOST%%\]*} ;;
  *:*) DNS_HOST=${DNS_HOST%:*} ;;
esac
if [ -z "$DNS_HOST" ]; then
  printf 'probe=%s dns=skipped http=none result=invalid-target base_url_has_no_authority\n' "$PROBE"
  exit 2
fi

# An IP literal is already an address: resolving it is a DNS query that cannot
# answer usefully (a PTR record is not the A/AAAA shape the classifier reads), so
# the lookup is skipped and the HTTP phase still runs.
case "$DNS_HOST" in
  *:*) DNS_LITERAL=1 ;;
  *[!0-9.]*|'') DNS_LITERAL=0 ;;
  *.*.*.*) DNS_LITERAL=1 ;;
  *) DNS_LITERAL=0 ;;
esac

DNS=skipped
HTTP=none
DETAIL=''

# ---- phase 1: name resolution ------------------------------------------------
# Best-effort and separately reported: a resolver tool's absence or its own odd
# output never becomes an outage claim. When the lookup already found no address
# the HTTP phase is skipped, because dialing a name with no address adds noise,
# not information.
#
# Availability is decided per candidate inside dns_probe, never by testing the
# whole configured value as one executable: an override may be a preference list,
# and `command -v "dig host"` fails while dig itself sits right there on PATH.
# A pre-gate over the combined string silently skipped the resolver that was
# actually installed and reported a lookup that never ran as dns=skipped.
dns_rcode() {
  local tool=$1 out=$2
  case "$tool" in
    dig) printf '%s\n' "$out" | sed -nE 's/^(;;.*status:|status:)[[:space:]]*([A-Za-z]+).*/\2/p' | head -n 1 | tr '[:lower:]' '[:upper:]' ;;
    host) printf '%s\n' "$out" | sed -nE 's/^Host .*not found:[[:space:]]*[0-9]+\(([A-Za-z]+)\).*/\1/p' | head -n 1 | tr '[:lower:]' '[:upper:]' ;;
  esac
}

dns_probe() {
  local tool out rc answer rcode saw_error=0 error_detail=''
  local -a tools=()
  # The override is one tool or a whitespace-separated preference list; unset
  # means this host's own candidates in order. `read -ra` splits on IFS without
  # pathname expansion, so a glob character in the list stays a literal token
  # instead of being expanded into unrelated filenames in the caller's cwd.
  read -ra tools <<< "${FM_PROVIDER_REACH_DNS_TOOL:-$DNS_DEFAULT_CANDIDATES}"
  [ "${#tools[@]}" -gt 0 ] || return 1
  for tool in "${tools[@]}"; do
    [ -n "$tool" ] || continue
    case "$tool" in
      /*) [ -x "$tool" ] || continue ;;
      *) command -v "$tool" >/dev/null 2>&1 || continue ;;
    esac
    # Both candidates take the bare hostname and no category argument. macOS
    # ships /usr/bin/dscacheutil, whose `-q` requires a valid directory-service
    # category (`host` is not one), so it answers any name with its usage block
    # and exit 64; calling it here recorded "the resolver errored" for names that
    # `dig` and `host` both reported as NXDOMAIN. It is therefore not a candidate.
    case "${tool##*/}" in
      dig) out=$(fm_run_timed "$TIMEOUT" "$tool" +noall +answer +comments "$DNS_HOST" A 2>/dev/null </dev/null) && rc=0 || rc=$? ;;
      *) out=$(fm_run_timed "$TIMEOUT" "$tool" "$DNS_HOST" 2>/dev/null </dev/null) && rc=0 || rc=$? ;;
    esac
    if [ "$rc" -eq 124 ]; then
      saw_error=1
      error_detail="timeout_after_${TIMEOUT}s"
      continue
    fi
    # The rcode is read from the resolver's header syntax only. An answer record
    # can legitimately contain a name such as `nxdomain.example.com`, and
    # scanning the whole output for rcode words misclassified that answer as a
    # lookup failure or a no-address reply.
    rcode=$(dns_rcode "${tool##*/}" "$out")
    case "$rcode" in
      SERVFAIL|FORMERR|REFUSED)
        saw_error=1
        error_detail="rc=${rc}"
        continue
        ;;
      NXDOMAIN)
        printf 'nxdomain %s\n' "$rcode"
        return 0
        ;;
    esac
    if [ "$rc" -ne 0 ]; then
      saw_error=1
      error_detail="rc=${rc}"
      continue
    fi
    # Only actual answer records count. `dig` prints its banner, SERVER, and WHEN
    # metadata on `;`-prefixed comment lines, and those can look like an address:
    # an IPv4 in `;; SERVER:` or a colon run in `;; WHEN:`. Matching them turned a
    # NODATA reply (status NOERROR, zero answers) into a false dns=ok and an
    # unnecessary request. Report the matched record, not the banner, as detail.
    case "${tool##*/}" in
      dig)
        answer=$(printf '%s\n' "$out" | awk '
          /^;; [A-Z]+ SECTION:/ { sections=1; inside=($0 ~ /^;; ANSWER SECTION:/); next }
          !/^;/ && NF && (!sections || inside) { print }
        ' | grep -E '(^|[[:space:]])([0-9]{1,3}\.){3}[0-9]{1,3}$' | head -n 1)
        ;;
      host) answer=$(printf '%s\n' "$out" | grep -E 'has address|IPv6 address' | head -n 1) ;;
      *) answer='' ;;
    esac
    if [ -n "$answer" ]; then
      printf 'ok %s\n' "$answer"
      return 0
    fi
    case "${tool##*/}" in
      dig)
        out=$(fm_run_timed "$TIMEOUT" "$tool" +noall +answer +comments "$DNS_HOST" AAAA 2>/dev/null </dev/null) && rc=0 || rc=$?
        if [ "$rc" -eq 124 ]; then
          saw_error=1
          error_detail="timeout_after_${TIMEOUT}s"
          continue
        fi
        rcode=$(dns_rcode dig "$out")
        case "$rcode" in
          SERVFAIL|FORMERR|REFUSED)
            saw_error=1
            error_detail="rc=${rc}"
            continue
            ;;
          NXDOMAIN)
            printf 'nxdomain %s\n' "$rcode"
            return 0
            ;;
        esac
        if [ "$rc" -ne 0 ]; then
          saw_error=1
          error_detail="rc=${rc}"
          continue
        fi
        answer=$(printf '%s\n' "$out" | awk '
          /^;; [A-Z]+ SECTION:/ { sections=1; inside=($0 ~ /^;; ANSWER SECTION:/); next }
          !/^;/ && NF && (!sections || inside) { print }
        ' | grep -E '(^|[[:space:]])[0-9a-fA-F]*:[0-9a-fA-F:]+$' | head -n 1)
        if [ -n "$answer" ]; then
          printf 'ok %s\n' "$answer"
          return 0
        fi
        if [ "$rcode" = NOERROR ] ||
          printf '%s\n' "$out" | grep -qiE 'no address|no records|has no'; then
          printf 'nxdomain no-address\n'
          return 0
        fi
        saw_error=1
        error_detail="rc=${rc}"
        continue
        ;;
      host)
        out=$(fm_run_timed "$TIMEOUT" "$tool" -t AAAA "$DNS_HOST" 2>/dev/null </dev/null) && rc=0 || rc=$?
        if [ "$rc" -eq 124 ]; then
          saw_error=1
          error_detail="timeout_after_${TIMEOUT}s"
          continue
        fi
        rcode=$(dns_rcode host "$out")
        case "$rcode" in
          SERVFAIL|FORMERR|REFUSED)
            saw_error=1
            error_detail="rc=${rc}"
            continue
            ;;
          NXDOMAIN)
            printf 'nxdomain %s\n' "$rcode"
            return 0
            ;;
        esac
        if [ "$rc" -ne 0 ]; then
          saw_error=1
          error_detail="rc=${rc}"
          continue
        fi
        answer=$(printf '%s\n' "$out" | grep -E 'has address|IPv6 address' | grep -E '[0-9a-fA-F]*:[0-9a-fA-F:]+' | head -n 1)
        if [ -n "$answer" ]; then
          printf 'ok %s\n' "$answer"
          return 0
        fi
        if printf '%s\n' "$out" | grep -qiE 'not found|no .*records|has no'; then
          printf 'nxdomain no-address\n'
          return 0
        fi
        saw_error=1
        error_detail="rc=${rc}"
        continue
        ;;
    esac
    # A successful but unfamiliar resolver is not proof that the name has no
    # address. Only explicitly recognized negative evidence may end the search.
    if printf '%s\n' "$out" | grep -qiE 'status:[[:space:]]*NXDOMAIN|\(NXDOMAIN\)|NOERROR-NODATA|no address|no records|has no' ||
      { printf '%s\n' "$out" | grep -qi 'status:[[:space:]]*NOERROR' && printf '%s\n' "$out" | grep -qi 'ANSWER: 0'; }; then
      printf 'nxdomain no-address\n'
      return 0
    fi
    saw_error=1
    error_detail="rc=${rc}"
  done
  if [ "$saw_error" = 1 ]; then
    printf 'fail %s\n' "$error_detail"
    return 0
  fi
  return 1
}

DNS_RESULT=''
if [ "$DNS_LITERAL" = 1 ]; then
  DETAIL="${DETAIL} dns_detail=dns_literal"
else
  DNS_RESULT=$(dns_probe)
fi
if [ -n "$DNS_RESULT" ]; then
  DNS=${DNS_RESULT%% *}
  DETAIL="${DETAIL} dns_detail=${DNS_RESULT#* }"
elif [ "$DNS_LITERAL" != 1 ]; then
  DNS=skipped
  DETAIL="${DETAIL} dns_tool_missing"
fi

# ---- emit terminal DNS-only results ------------------------------------------
if [ "$DNS" = nxdomain ]; then
  printf 'probe=%s dns=%s http=none result=unreachable%s\n' "$PROBE" "$DNS" "$DETAIL"
  exit 20
fi
if [ "$DNS" = fail ]; then
  DNS=unknown
fi

# ---- phase 2: one unauthenticated HTTP request -------------------------------
# Only an armed test suite may redirect the request away from this host's curl; a
# leaked variable alone does nothing without the suite marker. Resolving the
# executable is one check, so "this surface cannot be probed" stays its own
# outcome (exit 64) rather than collapsing into a connection failure.
CURL_CMD=curl
if [ "${FM_TEST_SEAM:-}" = 1 ] && [ -n "${FM_PROVIDER_REACH_CURL_CMD:-}" ]; then
  CURL_CMD=$FM_PROVIDER_REACH_CURL_CMD
fi
command -v "$CURL_CMD" >/dev/null 2>&1 || {
  printf 'probe=%s dns=%s http=none result=tool-missing curl_not_installed%s\n' "$PROBE" "$DNS" "$DETAIL"
  exit 64
}

DETAIL="${DETAIL} route=$PROXY_MODE"

# The response body is irrelevant to the fact being collected and is discarded to
# /dev/null; only the status code is captured. No temp file is created, so a
# streaming endpoint cannot consume disk and there is no predictable path for a
# local attacker to redirect. A valid code survives curl's non-zero exit (for
# example a truncated body after a 2xx header); only an absent or malformed code
# becomes 000.
HTTP_CODE=$(fm_run_timed "$TIMEOUT" "$CURL_CMD" -q --globoff -sS -o /dev/null -w '%{http_code}' \
  --max-time "$TIMEOUT" "$BASE" </dev/null 2>/dev/null)
case "$HTTP_CODE" in
  ''|*[!0-9]*) HTTP_CODE=000 ;;
esac
HTTP=$HTTP_CODE

RESULT=unreachable
case "$HTTP_CODE" in
  2??) RESULT=reachable ;;
  401|403) RESULT=routed-auth ;;
  000) RESULT=unreachable ;;
  5??) RESULT=server-error ;;
  *) RESULT=server-error ;;
esac
if [ "$HTTP_CODE" = 000 ]; then
  DETAIL="${DETAIL} reason=no_connection"
fi

printf 'probe=%s dns=%s http=%s result=%s%s\n' "$PROBE" "$DNS" "$HTTP" "$RESULT" "$DETAIL"
case "$RESULT" in
  reachable) exit 0 ;;
  routed-auth) exit 10 ;;
  server-error) exit 11 ;;
  *) exit 20 ;;
esac
