#!/bin/bash
# @parseArger-begin
# @parseArger-help "AI devbox installer: node/docker/git (always installed) + optional zsh, codex, claude, opencode, t3, CLIProxyAPI, hermes. Idempotent via state file. Supports multiple OpenAI-compatible providers." --option "help" --short-option "h"
# @parseArger-version "1.0.0" --option "version" --short-option "v"
# @parseArger-verbose --option "verbose" --level "0" --quiet-option "quiet"
_has_colors=0
if [ -t 1 ]; then # Check if stdout is a terminal
	ncolors=$(tput colors 2>/dev/null)
	if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
		_has_colors=1
	fi
fi
# @parseArger-declarations
# @parseArger opt node-version "Node.js version to install (official NodeSource way)" --short n --default-value "24"
# @parseArger opt provider "OpenAI-compatible upstream provider, repeatable. Format: name=NAME base=URL key=KEY models=M1,M2[,M3...]" --short p --repeat
# @parseArger opt codex-login-method "How to authenticate codex when available: oauth|api-key|skip" --default-value "skip" --one-of "oauth" --one-of "api-key" --one-of "skip"
# @parseArger opt bind-ip "LAN IP to expose services on; empty = localhost only" --short b --default-value ""
# @parseArger opt t3-port "Port for the t3 server" --default-value "3773"
# @parseArger opt cliproxy-port "Port for CLIProxyAPI" --default-value "8317"
# @parseArger opt hermes-port "Port for the hermes dashboard" --default-value "9119"
# @parseArger opt state-file "Path to the idempotency state file" --default-value "/home/didi/.ai-devbox/.installed"
# @parseArger opt force-step "Re-run a single named step (repeatable): git,docker,node,zsh,codex,claude,opencode,t3,cliproxy,hermes,wire,verify" --repeat
# @parseArger opt cliproxy-key "Proxy auth token agents use; auto-generated if unset" --default-value ""
# @parseArger opt mgmt-key "CLIProxyAPI management panel password; auto-generated if unset" --default-value ""
# @parseArger opt claudex-model "Model claudex drives via Claude Code interface" --default-value "gpt-5.6-sol"
# @parseArger opt glaude-model "Model glaude drives via Claude Code interface" --default-value "glm-5.2"
# @parseArger opt cheap-model "Cheaper model for the glaude haiku slot and claude-haiku proxy aliases (e.g. glm-4.7); empty = same as glaude-model" --default-value ""
# @parseArger flag with-zsh "Install zsh and set as default shell" --on
# @parseArger flag with-codex "Install codex CLI and wire it through CLIProxyAPI" --on
# @parseArger flag with-claude "Install claude-code and wire it through CLIProxyAPI" --on
# @parseArger flag with-opencode "Install opencode and wire it through CLIProxyAPI" --on
# @parseArger flag with-t3 "Install t3 harness as a systemd user service" --on
# @parseArger flag with-cliproxy "Install CLIProxyAPI as a systemd user service" --on
# @parseArger flag with-hermes "Install hermes-agent via docker compose" --on
# @parseArger flag force "Ignore the state file and re-run every enabled step" --short f
# @parseArger flag dry-run "Print each action without executing it" --short d
# @parseArger flag skip-verify "Do not run end-to-end agent calls (avoids token cost)" --on
# @parseArger flag with-gh "Install GitHub CLI (gh) via official repo — requires sudo"
# @parseArger flag with-claudex "Install claudex wrapper: Claude Code driving gpt-5.6-sol via proxy (on by default)" --on
# @parseArger flag with-glaude "Install glaude wrapper: Claude Code driving GLM via proxy (on by default)" --on
# @parseArger flag with-grok "Install grok CLI (x.ai build) via official install script (on by default)" --on
# @parseArger-declarations-end

# @parseArger-utils
_helpHasBeenPrinted=1;
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)";
# @parseArger-utils-end

# @parseArger-parsing

__cli_arg_count=$#;

die()
{
	local _ret=1
    if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
   	_ret="$2"
    fi
	test "${_PRINT_HELP:-no}" = yes && print_help >&2
	log "$1" -3 >&2
	exit "${_ret}"
}


begins_with_short_option()
{
	local first_option all_short_options=''
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# POSITIONALS ARGUMENTS
_positionals=();
_optional_positionals=();
# OPTIONALS ARGUMENTS
_arg_node_version="24"
_arg_provider=()
_arg_codex_login_method="skip"
_one_of_arg_codex_login_method=("oauth" "api-key" "skip" );
_arg_bind_ip=""
_arg_t3_port="3773"
_arg_cliproxy_port="8317"
_arg_hermes_port="9119"
_arg_state_file="/home/didi/.ai-devbox/.installed"
_arg_force_step=()
_arg_cliproxy_key=""
_arg_mgmt_key=""
_arg_claudex_model="gpt-5.6-sol"
_arg_glaude_model="glm-5.2"
_arg_cheap_model=""
# FLAGS
_arg_with_zsh="on"
_arg_with_codex="on"
_arg_with_claude="on"
_arg_with_opencode="on"
_arg_with_t3="on"
_arg_with_cliproxy="on"
_arg_with_hermes="on"
_arg_force="off"
_arg_dry_run="off"
_arg_skip_verify="on"
_arg_with_gh="off"
_arg_with_claudex="on"
_arg_with_glaude="on"
_arg_with_grok="on"
# NESTED
_verbose_level="0";



print_help()
{
	_triggerSCHelp=1;

	if [[ "$_helpHasBeenPrinted" == "1" ]]; then
		_helpHasBeenPrinted=0;
		echo -e "AI devbox installer: node/docker/git (always installed) + optional zsh, codex, claude, opencode, t3, CLIProxyAPI, hermes. Idempotent via state file. Supports multiple OpenAI-compatible providers.:"
	echo -e "	-n, --node-version <node-version>: Node.js version to install (official NodeSource way) [default: ' 24 ']"
	echo -e "	-p, --provider <provider>: OpenAI-compatible upstream provider, repeatable. Format: name=NAME base=URL key=KEY models=M1,M2[,M3...], repeatable"
	echo -e "	--codex-login-method <codex-login-method>: How to authenticate codex when available: oauth|api-key|skip [default: ' skip '] [one of 'oauth' 'api-key' 'skip']"
	echo -e "	-b, --bind-ip <bind-ip>: LAN IP to expose services on; empty = localhost only [default: '  ']"
	echo -e "	--t3-port <t3-port>: Port for the t3 server [default: ' 3773 ']"
	echo -e "	--cliproxy-port <cliproxy-port>: Port for CLIProxyAPI [default: ' 8317 ']"
	echo -e "	--hermes-port <hermes-port>: Port for the hermes dashboard [default: ' 9119 ']"
	echo -e "	--state-file <state-file>: Path to the idempotency state file [default: ' /home/didi/.ai-devbox/.installed ']"
	echo -e "	--force-step <force-step>: Re-run a single named step (repeatable): git,docker,node,zsh,codex,claude,opencode,t3,cliproxy,hermes,wire,verify, repeatable"
	echo -e "	--cliproxy-key <cliproxy-key>: Proxy auth token agents use; auto-generated if unset [default: '  ']"
	echo -e "	--mgmt-key <mgmt-key>: CLIProxyAPI management panel password; auto-generated if unset [default: '  ']"
	echo -e "	--claudex-model <claudex-model>: Model claudex drives via Claude Code interface [default: ' gpt-5.6-sol ']"
	echo -e "	--glaude-model <glaude-model>: Model glaude drives via Claude Code interface [default: ' glm-5.2 ']"
	echo -e "	--cheap-model <cheap-model>: Cheaper model for the glaude haiku slot and claude-haiku proxy aliases (e.g. glm-4.7); empty = same as glaude-model [default: '  ']"
	echo -e "	--with-zsh|--no-with-zsh: Install zsh and set as default shell, on by default (use --no-with-zsh to turn it off)"
	echo -e "	--with-codex|--no-with-codex: Install codex CLI and wire it through CLIProxyAPI, on by default (use --no-with-codex to turn it off)"
	echo -e "	--with-claude|--no-with-claude: Install claude-code and wire it through CLIProxyAPI, on by default (use --no-with-claude to turn it off)"
	echo -e "	--with-opencode|--no-with-opencode: Install opencode and wire it through CLIProxyAPI, on by default (use --no-with-opencode to turn it off)"
	echo -e "	--with-t3|--no-with-t3: Install t3 harness as a systemd user service, on by default (use --no-with-t3 to turn it off)"
	echo -e "	--with-cliproxy|--no-with-cliproxy: Install CLIProxyAPI as a systemd user service, on by default (use --no-with-cliproxy to turn it off)"
	echo -e "	--with-hermes|--no-with-hermes: Install hermes-agent via docker compose, on by default (use --no-with-hermes to turn it off)"
	echo -e "	-f|--force|--no-force: Ignore the state file and re-run every enabled step"
	echo -e "	-d|--dry-run|--no-dry-run: Print each action without executing it"
	echo -e "	--skip-verify|--no-skip-verify: Do not run end-to-end agent calls (avoids token cost), on by default (use --no-skip-verify to turn it off)"
	echo -e "	--with-gh|--no-with-gh: Install GitHub CLI (gh) via official repo — requires sudo"
	echo -e "	--with-claudex|--no-with-claudex: Install claudex wrapper: Claude Code driving gpt-5.6-sol via proxy (on by default), on by default (use --no-with-claudex to turn it off)"
	echo -e "	--with-glaude|--no-with-glaude: Install glaude wrapper: Claude Code driving GLM via proxy (on by default), on by default (use --no-with-glaude to turn it off)"
	echo -e "	--with-grok|--no-with-grok: Install grok CLI (x.ai build) via official install script (on by default), on by default (use --no-with-grok to turn it off)"
	echo -e "Usage :
	$0 [--node-version <value>] [--provider <value>] [--codex-login-method <value>] [--bind-ip <value>] [--t3-port <value>] [--cliproxy-port <value>] [--hermes-port <value>] [--state-file <value>] [--force-step <value>] [--cliproxy-key <value>] [--mgmt-key <value>] [--claudex-model <value>] [--glaude-model <value>] [--cheap-model <value>] [--[no-]with-zsh] [--[no-]with-codex] [--[no-]with-claude] [--[no-]with-opencode] [--[no-]with-t3] [--[no-]with-cliproxy] [--[no-]with-hermes] [--[no-]force] [--[no-]dry-run] [--[no-]skip-verify] [--[no-]with-gh] [--[no-]with-claudex] [--[no-]with-glaude] [--[no-]with-grok]";
	fi

}

log() {
	local _arg_msg="${1}";
	local _arg_level="${2:-0}";
	if [ "${_arg_level}" -le "${_verbose_level}" ]; then
		case "$_arg_level" in
			-3)
				_arg_COLOR="\033[0;31m";
				;;
			-2)
				_arg_COLOR="\033[0;33m";
				;;
			-1)
				_arg_COLOR="\033[1;33m";
				;;
			1)
				_arg_COLOR="\033[0;32m";
				;;
			2)
				_arg_COLOR="\033[1;36m";
				;;
			3)
				_arg_COLOR="\033[0;36m";
				;;
			*)
				_arg_COLOR="\033[0m";
				;;
		esac
		if [ "${_has_colors}" == "1" ]; then
			echo -e "${_arg_COLOR}${_arg_msg}\033[0m";
		else
			echo "${_arg_msg}";
		fi
	fi
}

parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-n|--node-version)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_node_version="$2"
				shift
				;;
			--node-version=*)
				_arg_node_version="${_key##--node-version=}"
				;;
			-n*)
				_arg_node_version="${_key##-n}"
				;;
			
			-p|--provider)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_provider+=("$2")
				shift
				;;
			--provider=*)
				_arg_provider+=("${_key##--provider=}")
				;;
			-p*)
				_arg_provider+=("${_key##-p}")
				;;
			
			--codex-login-method)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_codex_login_method="$2"
				if [[ "${#_one_of_arg_codex_login_method[@]}" -gt 0 ]];then [[ "${_one_of_arg_codex_login_method[*]}" =~ (^|[[:space:]])"$_arg_codex_login_method"($|[[:space:]]) ]] || die "codex-login-method must be one of: oauth api-key skip";fi
				shift
				;;
			--codex-login-method=*)
				_arg_codex_login_method="${_key##--codex-login-method=}"
				if [[ "${#_one_of_arg_codex_login_method[@]}" -gt 0 ]];then [[ "${_one_of_arg_codex_login_method[*]}" =~ (^|[[:space:]])"$_arg_codex_login_method"($|[[:space:]]) ]] || die "codex-login-method must be one of: oauth api-key skip";fi
				;;
			
			-b|--bind-ip)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_bind_ip="$2"
				shift
				;;
			--bind-ip=*)
				_arg_bind_ip="${_key##--bind-ip=}"
				;;
			-b*)
				_arg_bind_ip="${_key##-b}"
				;;
			
			--t3-port)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_t3_port="$2"
				shift
				;;
			--t3-port=*)
				_arg_t3_port="${_key##--t3-port=}"
				;;
			
			--cliproxy-port)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_cliproxy_port="$2"
				shift
				;;
			--cliproxy-port=*)
				_arg_cliproxy_port="${_key##--cliproxy-port=}"
				;;
			
			--hermes-port)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_hermes_port="$2"
				shift
				;;
			--hermes-port=*)
				_arg_hermes_port="${_key##--hermes-port=}"
				;;
			
			--state-file)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_state_file="$2"
				shift
				;;
			--state-file=*)
				_arg_state_file="${_key##--state-file=}"
				;;
			
			--force-step)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_force_step+=("$2")
				shift
				;;
			--force-step=*)
				_arg_force_step+=("${_key##--force-step=}")
				;;
			
			--cliproxy-key)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_cliproxy_key="$2"
				shift
				;;
			--cliproxy-key=*)
				_arg_cliproxy_key="${_key##--cliproxy-key=}"
				;;
			
			--mgmt-key)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_mgmt_key="$2"
				shift
				;;
			--mgmt-key=*)
				_arg_mgmt_key="${_key##--mgmt-key=}"
				;;
			
			--claudex-model)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_claudex_model="$2"
				shift
				;;
			--claudex-model=*)
				_arg_claudex_model="${_key##--claudex-model=}"
				;;
			
			--glaude-model)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_glaude_model="$2"
				shift
				;;
			--glaude-model=*)
				_arg_glaude_model="${_key##--glaude-model=}"
				;;
			
			--cheap-model)
				test $# -lt 2 && die "Missing value for the option: '$_key'" 1
				_arg_cheap_model="$2"
				shift
				;;
			--cheap-model=*)
				_arg_cheap_model="${_key##--cheap-model=}"
				;;
			
			--with-zsh)
				_arg_with_zsh="on"
				;;
			--no-with-zsh)
				_arg_with_zsh="off"
				;;
			--with-codex)
				_arg_with_codex="on"
				;;
			--no-with-codex)
				_arg_with_codex="off"
				;;
			--with-claude)
				_arg_with_claude="on"
				;;
			--no-with-claude)
				_arg_with_claude="off"
				;;
			--with-opencode)
				_arg_with_opencode="on"
				;;
			--no-with-opencode)
				_arg_with_opencode="off"
				;;
			--with-t3)
				_arg_with_t3="on"
				;;
			--no-with-t3)
				_arg_with_t3="off"
				;;
			--with-cliproxy)
				_arg_with_cliproxy="on"
				;;
			--no-with-cliproxy)
				_arg_with_cliproxy="off"
				;;
			--with-hermes)
				_arg_with_hermes="on"
				;;
			--no-with-hermes)
				_arg_with_hermes="off"
				;;
			-f|--force)
				_arg_force="on"
				;;
			--no-force)
				_arg_force="off"
				;;
			-d|--dry-run)
				_arg_dry_run="on"
				;;
			--no-dry-run)
				_arg_dry_run="off"
				;;
			--skip-verify)
				_arg_skip_verify="on"
				;;
			--no-skip-verify)
				_arg_skip_verify="off"
				;;
			--with-gh)
				_arg_with_gh="on"
				;;
			--no-with-gh)
				_arg_with_gh="off"
				;;
			--with-claudex)
				_arg_with_claudex="on"
				;;
			--no-with-claudex)
				_arg_with_claudex="off"
				;;
			--with-glaude)
				_arg_with_glaude="on"
				;;
			--no-with-glaude)
				_arg_with_glaude="off"
				;;
			--with-grok)
				_arg_with_grok="on"
				;;
			--no-with-grok)
				_arg_with_grok="off"
				;;
			-h|--help)
				print_help;
				exit 0;
				;;
			-h*)
				print_help;
				exit 0;
				;;
			-v|--version)
				print_version;
				exit 0;
				;;
			-v*)
				print_version;
				exit 0;
				;;
			--verbose)
				if [ $# -lt 2 ];then
					_verbose_level="$((_verbose_level + 1))";
				else
					_verbose_level="$2";
					shift;
				fi
				;;
			--quiet)
				if [ $# -lt 2 ];then
					_verbose_level="$((_verbose_level - 1))";
				else
					_verbose_level="-$2";
					shift;
				fi
				;;
			
				*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}


handle_passed_args_count()
{
	local _required_args_string=""
	if [ "${_positionals_count}" -gt 0 ] && [ "$_helpHasBeenPrinted" == "1" ];then
		_PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect at most 0 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}').\n\t${_positionals[*]}" 1
	fi
	if [ "${_positionals_count}" -lt 0 ] && [ "$_helpHasBeenPrinted" == "1" ];then
		_PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require at least 0 (namely: $_required_args_string), but got only ${_positionals_count}.
	${_positionals[*]}" 1;
	fi
}


assign_positional_args()
{
	local _positional_name _shift_for=$1;
	_positional_names="";
	shift "$_shift_for"
	for _positional_name in ${_positional_names};do
		test $# -gt 0 || break;
		eval "if [ \"\$_one_of${_positional_name}\" != \"\" ];then [[ \"\${_one_of${_positional_name}[*]}\" =~ \"\${1}\" ]];fi" || die "${_positional_name} must be one of: $(eval "echo \"\${_one_of${_positional_name}[*]}\"")" 1;
		local _match_var="_match${_positional_name}";
		local _regex="${!_match_var}";
		if [ -n "$_regex" ]; then
			[[ "${1}" =~ $_regex ]] || die "${_positional_name} does not match pattern: $_regex"
		fi
		eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an ParseArger bug." 1;
		shift;
	done
}

print_debug()
{
	print_help
	# shellcheck disable=SC2145
	echo "DEBUG: $0 $@";
	
	echo -e "	node-version: ${_arg_node_version}";
	echo -e "	provider: ${_arg_provider[*]}";
	echo -e "	codex-login-method: ${_arg_codex_login_method}";
	echo -e "	bind-ip: ${_arg_bind_ip}";
	echo -e "	t3-port: ${_arg_t3_port}";
	echo -e "	cliproxy-port: ${_arg_cliproxy_port}";
	echo -e "	hermes-port: ${_arg_hermes_port}";
	echo -e "	state-file: ${_arg_state_file}";
	echo -e "	force-step: ${_arg_force_step[*]}";
	echo -e "	cliproxy-key: ${_arg_cliproxy_key}";
	echo -e "	mgmt-key: ${_arg_mgmt_key}";
	echo -e "	claudex-model: ${_arg_claudex_model}";
	echo -e "	glaude-model: ${_arg_glaude_model}";
	echo -e "	cheap-model: ${_arg_cheap_model}";
	echo -e "	with-zsh: ${_arg_with_zsh}";
	echo -e "	with-codex: ${_arg_with_codex}";
	echo -e "	with-claude: ${_arg_with_claude}";
	echo -e "	with-opencode: ${_arg_with_opencode}";
	echo -e "	with-t3: ${_arg_with_t3}";
	echo -e "	with-cliproxy: ${_arg_with_cliproxy}";
	echo -e "	with-hermes: ${_arg_with_hermes}";
	echo -e "	force: ${_arg_force}";
	echo -e "	dry-run: ${_arg_dry_run}";
	echo -e "	skip-verify: ${_arg_skip_verify}";
	echo -e "	with-gh: ${_arg_with_gh}";
	echo -e "	with-claudex: ${_arg_with_claudex}";
	echo -e "	with-glaude: ${_arg_with_glaude}";
	echo -e "	with-grok: ${_arg_with_grok}";

}


print_version()
{
	echo "1.0.0";
}


on_interrupt() {
	die Process aborted! 130;
}


parse_commandline "$@";
handle_passed_args_count;
assign_positional_args 1 "${_positionals[@]}";
trap on_interrupt INT;




# @parseArger-parsing-end
# print_debug "$@"
# @parseArger-end

# ============================================================================
# FUNCTIONAL BODY — AI devbox installer
# Everything below is hand-written logic (not regenerated by parseArger).
# Edit freely. Re-running `parseArger parse --inplace` only touches code
# between the @parseArger-parsing markers above.
# ============================================================================

# ---------------------------------------------------------------------------
# PATH setup: ensure user npm-global + local bin are on PATH for this run
# ---------------------------------------------------------------------------
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# LOGGING / OUTPUT
# ---------------------------------------------------------------------------
# Reuse parseArger's color helpers (_has_colors, etc.) if present.
_log_info()  { printf '%s\n' "$*"; }
_log_ok()    { [ "$_has_colors" = 1 ] && printf '\033[0;32m✓\033[0m %s\n' "$*" || printf '✓ %s\n' "$*"; }
_log_warn()  { [ "$_has_colors" = 1 ] && printf '\033[0;33m!\033[0m %s\n' "$*" || printf '! %s\n' "$*"; }
_log_step()  { [ "$_has_colors" = 1 ] && printf '\n\033[0;36m▶\033[0m %s\n' "$*" || printf '\n>> %s\n' "$*"; }
_log_fail()  { [ "$_has_colors" = 1 ] && printf '\033[0;31m✗\033[0m %s\n' "$*" >&2 || printf '✗ %s\n' "$*" >&2; }

# die() is provided by parseArger's scaffold (above). Reuse it.
# run: executes a command unless --dry-run is set. Logs what it's doing.
run() {
  if [ "${_arg_dry_run}" = "on" ]; then
    printf '   [dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

# dock: run a docker/compose command, prepending sudo ONLY if the current
# session can't reach the daemon without it (i.e. the docker group was just
# added but isn't active yet). This lets the script run end-to-end in one go.
_docker_sudo_cache=""
_docker_needs_sudo() {
  if [ -z "$_docker_sudo_cache" ]; then
    if docker ps >/dev/null 2>&1; then
      _docker_sudo_cache="no"
    else
      _docker_sudo_cache="yes"
    fi
  fi
  [ "$_docker_sudo_cache" = "yes" ]
}
dock() {
  if [ "${_arg_dry_run}" = "on" ]; then
    printf '   [dry-run] %s\n' "$*"
    return 0
  fi
  if _docker_needs_sudo; then sudo "$@"; else "$@"; fi
}

# ---------------------------------------------------------------------------
# OS / DISTRO DETECTION
# ---------------------------------------------------------------------------
detect_distro() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    _DISTRO_ID="${ID:-unknown}"
    _DISTRO_FAMILY="${ID_LIKE:-}"
    _DISTRO_VERSION="${VERSION_ID:-}"
  else
    _DISTRO_ID="unknown"
    _DISTRO_FAMILY=""
    _DISTRO_VERSION=""
  fi
  # Normalize family
  case "$_DISTRO_ID" in
    fedora|rhel|rocky|almalinux|centos) _PM="dnf"; _PM_FAMILY="rhel" ;;
    debian|ubuntu|linuxmint|pop)        _PM="apt"; _PM_FAMILY="debian" ;;
    arch|manjaro|endeavouros)           _PM="pacman"; _PM_FAMILY="arch" ;;
    alpine)                             _PM="apk"; _PM_FAMILY="alpine" ;;
    *)                                  _PM=""; _PM_FAMILY="" ;;
  esac
  _log_info "Detected: $_DISTRO_ID ($_DISTRO_VERSION) [family: ${_PM_FAMILY:-none}, pm: ${_PM:-none}]"
}

# root_cmd <cmd...>: run a command as root (sudo if not already root).
# Single source of truth for privilege escalation — honors dry-run.
root_cmd() {
  if [ "$(id -u)" -eq 0 ]; then
    run "$@"
  else
    run sudo "$@"
  fi
}

# pm_install <pkg...>: install packages via the detected package manager.
pm_install() {
  [ -n "$_PM" ] || die "No supported package manager detected (tried dnf/apt/pacman/apk)."
  case "$_PM" in
    dnf)    root_cmd dnf install -y "$@" ;;
    apt)    root_cmd apt-get install -y "$@" ;;
    pacman) root_cmd pacman -S --noconfirm --needed "$@" ;;
    apk)    root_cmd apk add --no-cache "$@" ;;
  esac
}

# pm_makecache: refresh the package index (apt update / dnf makecache).
pm_makecache() {
  case "$_PM" in
    apt) root_cmd apt-get update ;;
    dnf) : ;;  # dnf auto-refreshes
    pacman) root_cmd pacman -Sy ;;
    apk) : ;;
  esac
}

# pm_add_repo <repo-or-url>: add a third-party repo, the distro-native way.
# rhel/dnf: adds via config-manager (dnf5 vs dnf4 auto-detected)
# debian/apt: treats arg as a sources.list line + needs separate key handling
#             (callers should use apt_add_repo_with_key for deb repos)
pm_add_repo() {
  case "$_PM_FAMILY" in
    rhel)
      if dnf5 --version >/dev/null 2>&1; then
        root_cmd dnf install -y dnf5-plugins || die "Failed to install dnf5-plugins"
        root_cmd dnf config-manager addrepo --from-repofile="$1" \
          || die "Failed to add repo (dnf5): $1"
      else
        root_cmd dnf config-manager --add-repo "$1" \
          || die "Failed to add repo (dnf4): $1"
      fi
      ;;
    debian)
      die "pm_add_repo: for apt, use apt_add_repo_with_key (deb repos need a keyring)"
      ;;
    *)
      die "pm_add_repo: not implemented for pm family '$_PM_FAMILY'"
      ;;
  esac
}

# apt_add_repo_with_key <keyring_url> <sources_list_line>
# Fetches the signing key into the keyring, writes the sources line, refreshes.
apt_add_repo_with_key() {
  local key_url="$1" src_line="$2"
  local kr
  kr="/usr/share/keyrings/$(basename "${key_url%.gpg}").gpg"
  root_cmd install -dm755 /usr/share/keyrings
  curl -fsSL "$key_url" | root_cmd tee "$kr" >/dev/null || die "Failed to write keyring from $key_url"
  root_cmd chmod go+r "$kr"
  echo "$src_line" | root_cmd tee /etc/apt/sources.list.d/_devbox_added.list >/dev/null
  pm_makecache
}

# build_deps_pkgs: echoes the native build-toolchain packages for the family.
# Used by t3 (node-pty) and anywhere compilation is needed. One place, DRY.
build_deps_pkgs() {
  case "$_PM_FAMILY" in
    rhel)    echo "make gcc gcc-c++ python3 python3-devel" ;;
    debian)  echo "make g++ python3" ;;
    arch)    echo "base-devel python" ;;
    *)       echo "" ;;
  esac
}

# prereqs_pkgs: the minimal network/archive toolset the rest of the script
# depends on (curl for downloads, ca-certificates for TLS, tar to extract).
# Minimal cloud images (debian/ubuntu minimal) do NOT ship these.
prereqs_pkgs() {
  case "$_PM_FAMILY" in
    rhel)    echo "curl ca-certificates tar" ;;
    debian)  echo "curl ca-certificates tar" ;;
    arch)    echo "curl ca-certificates tar" ;;
    alpine)  echo "curl ca-certificates tar" ;;
    *)       echo "curl ca-certificates tar" ;;
  esac
}

# ensure_prereqs: install curl/ca-certificates/tar if missing. Runs BEFORE any
# step — everything downstream (NodeSource, get.docker.com, CLIProxyAPI dl)
# assumes these exist. Cheap and idempotent.
ensure_prereqs() {
  local missing=""
  for p in curl tar; do
    command -v "$p" >/dev/null 2>&1 || missing="$missing $p"
  done
  # ca-certificates has no single binary to check; test via the cert bundle
  if [ ! -d /etc/ssl/certs ] || [ -z "$(ls -A /etc/ssl/certs 2>/dev/null)" ]; then
    missing="$missing ca-certificates"
  fi
  if [ -n "$missing" ]; then
    _log_step "prerequisites (curl, ca-certificates, tar)"
    _log_info "Installing missing: $missing"
    local pkgs; pkgs="$(prereqs_pkgs)"
    pm_install $pkgs || die "Failed to install prerequisites ($pkgs)"
    _log_ok "prerequisites installed"
  fi
}

# ---------------------------------------------------------------------------
# STATE FILE / IDEMPOTENCY
# Records completed steps. step_done <name> marks; should_run <name> decides.
# ---------------------------------------------------------------------------
_state_dir() { dirname "$_arg_state_file"; }

init_state() {
  if [ "${_arg_dry_run}" != "on" ]; then
    mkdir -p "$(_state_dir)" || die "Cannot create state dir: $(_state_dir)"
    [ -f "$_arg_state_file" ] || : > "$_arg_state_file"
  fi
}

# step_done <name> — append marker (idempotent, no dupes)
step_done() {
  local name="$1"
  if [ "${_arg_dry_run}" = "on" ]; then return 0; fi
  grep -qxF "$name" "$_arg_state_file" 2>/dev/null || printf '%s\n' "$name" >> "$_arg_state_file"
}

# should_run <name> — true (0) if the step should execute, false (1) if done
# Honors --force (always run) and --force-step <name> (run that one).
should_run() {
  local name="$1"
  [ "${_arg_force}" = "on" ] && return 0
  for s in "${_arg_force_step[@]}"; do [ "$s" = "$name" ] && return 0; done
  if grep -qxF "$name" "$_arg_state_file" 2>/dev/null; then
    _log_info "  (already done: $name — skipping. Use --force-step=$name to redo)"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# SECRETS — auto-generate if not provided
# ---------------------------------------------------------------------------
ensure_secrets() {
  local state_dir; state_dir="$(_state_dir)"
  local sec_file="$state_dir/.secrets.env"
  if [ -z "$_arg_cliproxy_key" ]; then
    if [ -f "$sec_file" ] && grep -q '^CLIPROXY_API_KEY=' "$sec_file" 2>/dev/null; then
      _arg_cliproxy_key="$(grep '^CLIPROXY_API_KEY=' "$sec_file" | cut -d= -f2-)"
    else
      _arg_cliproxy_key="$(run openssl rand -hex 32)"
    fi
  fi
  if [ -z "$_arg_mgmt_key" ]; then
    if [ -f "$sec_file" ] && grep -q '^MGMT_KEY=' "$sec_file" 2>/dev/null; then
      _arg_mgmt_key="$(grep '^MGMT_KEY=' "$sec_file" | cut -d= -f2-)"
    else
      _arg_mgmt_key="$(run openssl rand -hex 32)"
    fi
  fi
  if [ "${_arg_dry_run}" != "on" ]; then
    ( umask 077; printf 'CLIPROXY_API_KEY=%s\nMGMT_KEY=%s\n' "$_arg_cliproxy_key" "$_arg_mgmt_key" > "$sec_file" )
  fi
  _log_info "Secrets ready (stored mode 600 at $sec_file)"
}

# ---------------------------------------------------------------------------
# PROVIDER PARSING — parses --provider 'name=.. base=.. key=.. models=..'
# Builds associative array _PROVIDERS_<n>_* and a count _PROVIDER_COUNT
# ---------------------------------------------------------------------------
declare -g _PROVIDER_COUNT=0
parse_providers() {
  local spec keyval k v
  for spec in "${_arg_provider[@]}"; do
    [ -z "$spec" ] && continue
    local _pname="" _pbase="" _pkey="" _pmodels="" _pcheap=""
    # split on spaces into key=val tokens
    local tokens; IFS=' ' read -r -a tokens <<< "$spec"
    for keyval in "${tokens[@]}"; do
      k="${keyval%%=*}"; v="${keyval#*=}"
      case "$k" in
        name)   _pname="$v" ;;
        base)   _pbase="$v" ;;
        key)    _pkey="$v" ;;
        models) _pmodels="$v" ;;
        cheap)  _pcheap="$v" ;;   # cheaper model for the haiku slot
      esac
    done
    [ -n "$_pname" ] && [ -n "$_pbase" ] || die "Provider spec missing name/base: '$spec'"
    [ -n "$_pkey" ]  || die "Provider '$_pname' missing key= (use key=\$ENV_VAR to expand at runtime)"
    # expand $VAR / ${VAR} in key
    _pkey="$(eval "printf '%s' \"$_pkey\"")"
    _PROVIDER_COUNT=$((_PROVIDER_COUNT + 1))
    declare -g "_PROVIDERS_${_PROVIDER_COUNT}_NAME=$_pname"
    declare -g "_PROVIDERS_${_PROVIDER_COUNT}_BASE=$_pbase"
    declare -g "_PROVIDERS_${_PROVIDER_COUNT}_KEY=$_pkey"
    declare -g "_PROVIDERS_${_PROVIDER_COUNT}_MODELS=$_pmodels"
    declare -g "_PROVIDERS_${_PROVIDER_COUNT}_CHEAP=$_pcheap"
    _log_info "Provider #$_PROVIDER_COUNT: $_pname ($_pbase) models=[$_pmodels] cheap=[$_pcheap]"
  done
}

# render_providers_yaml — emits openai-compatibility block for CLIProxyAPI config
render_providers_yaml() {
  local i n m
  n="$_PROVIDER_COUNT"
  if [ "$n" -eq 0 ]; then
    printf '# (no providers configured)\n'
    return
  fi
  printf 'openai-compatibility:\n'
  for i in $(seq 1 "$n"); do
    local nm bt ky ml
    nm="$(eval "printf '%s' \"\$_PROVIDERS_${i}_NAME\"")"
    bt="$(eval "printf '%s' \"\$_PROVIDERS_${i}_BASE\"")"
    ky="$(eval "printf '%s' \"\$_PROVIDERS_${i}_KEY\"")"
    ml="$(eval "printf '%s' \"\$_PROVIDERS_${i}_MODELS\"")"
    printf '  - name: "%s"\n' "$nm"
    printf '    base-url: "%s"\n' "$bt"
    printf '    api-key-entries:\n'
    printf '      - api-key: "%s"\n' "$ky"
    if [ -n "$ml" ]; then
      printf '    models:\n'
      # split models on comma
      local marr; IFS=',' read -r -a marr <<< "$ml"
      for m in "${marr[@]}"; do
        printf '      - { name: "%s", alias: "%s" }\n' "$m" "$m"
      done
    fi
    # claude-haiku aliases routing to the cheap model (so the glaude haiku slot,
    # which t3 sends as claude-haiku-4-5 etc., lands on the cheaper backend).
    local ch; ch="$(eval "printf '%s' \"\$_PROVIDERS_${i}_CHEAP\"")"
    if [ -n "$ch" ]; then
      for alias in "claude-haiku-4-5" "claude-haiku-4.5" "claude-haiku-4-5-20251001"; do
        printf '      - { name: "%s", alias: "%s" }\n' "$ch" "$alias"
      done
    fi
  done
}

# ---------------------------------------------------------------------------
# STEPS — each guarded by should_run / step_done
# ---------------------------------------------------------------------------

step_git() {
  _log_step "git (always installed)"
  should_run git || return 0
  if command -v git >/dev/null 2>&1; then
    _log_ok "git present: $(git --version)"
    step_done git; return 0
  fi
  _log_info "git missing — installing"
  pm_install git || die "Failed to install git"
  command -v git >/dev/null 2>&1 || die "git still not on PATH after install"
  _log_ok "git installed: $(git --version)"
  step_done git
}

step_docker() {
  _log_step "docker (always installed, official way)"
  should_run docker || return 0
  # helper: is $USER in the docker group (per /etc/group)?
  _in_docker_group() { grep -E "^docker:" /etc/group 2>/dev/null | grep -qw "$USER"; }
  if command -v docker >/dev/null 2>&1; then
    _log_ok "docker present: $(docker --version)"
  else
    _log_info "docker missing — installing via official get.docker.com"
    run sh -c 'curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sh /tmp/get-docker.sh' \
      || die "Failed to install docker (official script)"
    # enable + start daemon
    root_cmd systemctl enable --now docker.service 2>/dev/null \
      || root_cmd systemctl enable --now docker 2>/dev/null \
      || _log_warn "could not enable docker service (may need manual: sudo systemctl enable --now docker)"
    command -v docker >/dev/null 2>&1 || die "docker still not on PATH after install"
    _log_ok "docker installed: $(docker --version)"
  fi
  # --- ensure the user is in the docker group so no sudo is needed ---
  # Group membership is checked at LOGIN, not mid-session. dock() handles the
  # gap by prepending sudo to docker commands until the group is active.
  # Only attempt this if a docker daemon is actually present (the group may not
  # exist on boxes where docker is stubbed or only partially set up).
  if command -v dockerd >/dev/null 2>&1 || getent group docker >/dev/null 2>&1; then
    if ! _in_docker_group; then
      _log_info "Adding $USER to the docker group (requires sudo)"
      # create the group if it somehow doesn't exist, then add the user
      getent group docker >/dev/null 2>&1 || root_cmd groupadd docker
      root_cmd usermod -aG docker "$USER" || die "Failed to add $USER to docker group"
      _log_ok "Added to docker group (active on next login; docker steps use sudo meanwhile)"
    fi
  else
    _log_warn "docker group absent and no dockerd found — skipping group setup (run 'sudo usermod -aG docker \$USER' after docker is fully installed)"
  fi
  step_done docker
}

step_node() {
  _log_step "node/npm (always installed, official NodeSource)"
  should_run node || return 0
  # t3 version constraint: ^22.16 || ^23.11 || >=24.10
  if command -v node >/dev/null 2>&1; then
    local have; have="$(node -v | sed 's/v//')"   # e.g. 24.18.0
    local major minor
    major="${have%%.*}"
    minor="$(printf '%s' "$have" | cut -d. -f2)"
    _log_info "node present: $have (t3 needs ^22.16 || ^23.11 || >=24.10)"
    # accept if: major 22 & minor>=16, OR major 23 & minor>=11, OR major>=24 & minor>=10
    if { [ "$major" = 22 ] && [ "$minor" -ge 16 ]; } \
    || { [ "$major" = 23 ] && [ "$minor" -ge 11 ]; } \
    || { [ "$major" -ge 24 ] && [ "$minor" -ge 10 ]; }; then
      _log_ok "node $have satisfies t3 requirements"
      step_done node; return 0
    else
      _log_warn "node $have too old for t3 — installing $_arg_node_version (LTS) via NodeSource"
    fi
  fi
  _log_info "Installing node $_arg_node_version via NodeSource (official)"
  case "$_PM_FAMILY" in
    debian|rhel)
      # NodeSource uses deb. vs rpm. by family; rest of the flow is identical.
      local sub; sub="deb"; [ "$_PM_FAMILY" = "rhel" ] && sub="rpm"
      run sh -c "curl -fsSL https://${sub}.nodesource.com/setup_${_arg_node_version}.x | sudo -E bash -" \
        || die "NodeSource setup failed"
      pm_install nodejs || die "Failed to install nodejs"
      ;;
    *)
      # fallback: nvm (user-space, no sudo)
      _log_info "No NodeSource support for $_PM_FAMILY — using nvm (user-space)"
      run sh -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash' \
        || die "nvm install failed"
      # shellcheck disable=SC1091
      run . "$HOME/.nvm/nvm.sh" && run nvm install "$_arg_node_version" && run nvm alias default "$_arg_node_version"
      ;;
  esac
  command -v node >/dev/null 2>&1 || die "node not on PATH after install"
  _log_ok "node installed: $(node --version)"
  step_done node
}

step_zsh() {
  [ "${_arg_with_zsh}" = "on" ] || { _log_info "zsh: skipped (--no-with-zsh)"; return 0; }
  _log_step "zsh"
  should_run zsh || return 0
  if command -v zsh >/dev/null 2>&1; then
    _log_ok "zsh present: $(zsh --version)"
  else
    pm_install zsh || die "Failed to install zsh"
    _log_ok "zsh installed"
  fi
  # set as default shell if not already (use root_cmd so it doesn't hang on a
  # password prompt in a non-interactive/headless run)
  if [ -n "$SHELL" ] && [ "$(basename "$SHELL")" != "zsh" ]; then
    _log_info "Setting zsh as default shell"
    root_cmd chsh -s "$(command -v zsh)" "$USER" \
      || _log_warn "chsh failed — run manually: sudo chsh -s $(command -v zsh) $USER"
  fi
  step_done zsh
}

step_cliproxy() {
  [ "${_arg_with_cliproxy}" = "on" ] || { _log_info "cliproxy: skipped (--no-with-cliproxy)"; return 0; }
  _log_step "CLIProxyAPI"
  should_run cliproxy || return 0
  local cdir="$HOME/cliproxyapi"
  local bind; bind="${_arg_bind_ip:-127.0.0.1}"
  # download if binary missing
  if [ ! -x "$cdir/cli-proxy-api" ]; then
    _log_info "Downloading CLIProxyAPI"
    if [ "${_arg_dry_run}" != "on" ]; then
      mkdir -p "$cdir"
      # resolve the versioned linux_amd64 asset URL from the latest release
      local url api_resp
      api_resp="$(curl -fsSL https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest 2>/dev/null || true)"
      url="$(printf '%s\n' "$api_resp" | grep -oE 'https://[^"]*linux_amd64\.tar\.gz' | head -1)"
      [ -n "$url" ] || die "Could not resolve CLIProxyAPI linux_amd64 release URL"
      curl -fsSL "$url" -o /tmp/cpa.tar.gz || die "Failed to download CLIProxyAPI"
      tar -xzf /tmp/cpa.tar.gz -C "$cdir" || die "Failed to extract CLIProxyAPI tarball"
      rm -f /tmp/cpa.tar.gz
      [ -x "$cdir/cli-proxy-api" ] || die "binary (cli-proxy-api) not found after extract"
      _log_ok "CLIProxyAPI downloaded"
    else
      printf '   [dry-run] download + extract CLIProxyAPI to %s\n' "$cdir"
    fi
  else
    _log_ok "CLIProxyAPI binary already present"
  fi
  # write config.yaml
  _log_info "Writing $cdir/config.yaml"
  local providers_yaml; providers_yaml="$(render_providers_yaml)"
  if [ "${_arg_dry_run}" != "on" ]; then
    cat > "$cdir/config.yaml" <<CPAEOF
host: "$bind"
port: ${_arg_cliproxy_port}
tls:
  enable: false
  cert: ""
  key: ""
remote-management:
  allow-remote: false
  secret-key: "${_arg_mgmt_key}"
  disable-control-panel: false
auth-dir: "~/.cli-proxy-api"
api-keys:
  - "${_arg_cliproxy_key}"
debug: false
pprof:
  enable: false
  addr: "127.0.0.1:8316"
${providers_yaml}
routing:
  strategy: "round-robin"
  session-affinity: false
  session-affinity-ttl: "1h"
request-retry: 3
CPAEOF
  fi
  # systemd user unit
  local udir="$HOME/.config/systemd/user"; run mkdir -p "$udir"
  if [ "${_arg_dry_run}" != "on" ]; then
    cat > "$udir/cliproxyapi.service" <<SVCEOF
[Unit]
Description=CLIProxyAPI (user service)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=%h/cliproxyapi
ExecStart=%h/cliproxyapi/cli-proxy-api -config %h/cliproxyapi/config.yaml
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
SVCEOF
  fi
  run systemctl --user daemon-reload
  run systemctl --user enable cliproxyapi.service 2>/dev/null
  run systemctl --user restart cliproxyapi.service 2>/dev/null
  _log_ok "CLIProxyAPI configured + service enabled"
  step_done cliproxy
}

# install one npm global pkg + verify on PATH
_npm_global() {
  local pkg="$1"
  _log_info "npm i -g $pkg"
  run npm install -g "$pkg" || die "Failed to install $pkg"
}

step_agents() {
  _log_step "Agent CLIs (codex/claude/opencode)"
  should_run agents || return 0
  # user npm prefix (avoid permission errors on /usr/lib)
  run npm config set prefix "$HOME/.npm-global"
  local line='export PATH="$HOME/.npm-global/bin:$PATH"'
  if [ "${_arg_dry_run}" != "on" ]; then
    for rc in "$HOME/.zshrc" "$HOME/.profile" "$HOME/.zshenv" "$HOME/.bashrc"; do
      touch "$rc"
      grep -qF '.npm-global/bin' "$rc" 2>/dev/null || printf '\n%s\n' "$line" >> "$rc"
    done
  fi
  if [ "${_arg_with_codex}" = "on" ]; then
    _log_info "codex"; _npm_global "@openai/codex"
    # ~/.codex/config.toml -> proxy (wire_api=responses, proxy serves /v1/responses)
    if [ "${_arg_dry_run}" != "on" ]; then
      mkdir -p "$HOME/.codex"
      cat > "$HOME/.codex/config.toml" <<CODEXEOF
# generated by devbox-setup.sh — routes through local CLIProxyAPI
model = "glm-5.2"
model_provider = "cliproxy"

[model_providers.cliproxy]
name = "CLIProxyAPI"
base_url = "http://127.0.0.1:${_arg_cliproxy_port}/v1"
wire_api = "responses"
env_key = "CLIPROXY_API_KEY"
CODEXEOF
    fi
  fi
  if [ "${_arg_with_claude}" = "on" ]; then
    _log_info "claude-code"; _npm_global "@anthropic-ai/claude-code"
  fi
  if [ "${_arg_with_opencode}" = "on" ]; then
    _log_info "opencode"; _npm_global "opencode-ai"
    if [ "${_arg_dry_run}" != "on" ]; then
      mkdir -p "$HOME/.config/opencode"
      cat > "$HOME/.config/opencode/opencode.json" <<OCEOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "cliproxy": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "CLIProxyAPI",
      "options": {
        "baseURL": "http://127.0.0.1:${_arg_cliproxy_port}/v1",
        "apiKey": "{env:CLIPROXY_API_KEY}"
      },
      "models": {
        "glm-5.2": { "name": "GLM 5.2" }
      }
    }
  }
}
OCEOF
    fi
  fi
  # write shared proxy env file sourced by all shells
  if [ "${_arg_dry_run}" != "on" ]; then
    ( umask 077; cat > "$HOME/.ai-proxy.env" <<ENVEOF
export CLIPROXY_API_KEY=${_arg_cliproxy_key}
export ANTHROPIC_BASE_URL=http://127.0.0.1:${_arg_cliproxy_port}
export ANTHROPIC_API_KEY=\$CLIPROXY_API_KEY
ENVEOF
    )
    # if a cheap model is set, export it so the glaude wrapper's haiku slot uses it
    if [ -n "${_arg_cheap_model:-}" ]; then
      printf 'export GLAUDE_HAIKU_MODEL=%s\n' "${_arg_cheap_model}" >> "$HOME/.ai-proxy.env"
      chmod 600 "$HOME/.ai-proxy.env"
    fi
    local src='[ -f ~/.ai-proxy.env ] && source ~/.ai-proxy.env'
    for rc in "$HOME/.zshrc" "$HOME/.profile" "$HOME/.zshenv" "$HOME/.bashrc"; do
      grep -qF 'ai-proxy.env' "$rc" 2>/dev/null || printf '\n%s\n' "$src" >> "$rc"
    done
  fi
  _log_ok "Agent CLIs installed + wired to proxy"
  step_done agents
}

step_gh() {
  [ "${_arg_with_gh}" = "on" ] || { _log_info "gh: skipped (off by default; --with-gh enables, requires sudo)"; return 0; }
  _log_step "GitHub CLI (gh)"
  should_run gh || return 0
  if command -v gh >/dev/null 2>&1; then
    _log_ok "gh present: $(gh --version | head -1)"
    step_done gh; return 0
  fi
  _log_info "Installing gh via official repo (requires sudo)"
  if [ "${_arg_dry_run}" != "on" ]; then
    case "$_PM_FAMILY" in
      rhel)
        pm_add_repo "https://cli.github.com/packages/rpm/gh-cli.repo"
        pm_install gh || die "Failed to install gh"
        ;;
      debian)
        local arch; arch="$(dpkg --print-architecture)"
        local kr="/usr/share/keyrings/githubcli-archive-keyring.gpg"
        apt_add_repo_with_key \
          "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
          "deb [arch=$arch signed-by=$kr] https://cli.github.com/packages stable main"
        pm_install gh || die "Failed to install gh"
        ;;
      *)
        die "gh install not implemented for pm family '$_PM_FAMILY' — install manually from https://github.com/cli/cli#installation"
        ;;
    esac
  else
    printf '   [dry-run] add gh repo + install gh via %s\n' "$_PM"
  fi
  command -v gh >/dev/null 2>&1 && _log_ok "gh installed: $(gh --version | head -1)"
  step_done gh
}

step_claudex_glaude() {
  # both default on; either off skips that one wrapper
  [ "${_arg_with_claudex}" = "on" ] || [ "${_arg_with_glaude}" = "on" ] \
    || { _log_info "claudex/glaude: both skipped"; return 0; }
  _log_step "Claude-Code wrappers (claudex / glaude)"
  should_run claudex_glaude || return 0
  # wrappers live in ~/.npm-global/bin so t3's PATH finds them
  local bindir="$HOME/.npm-global/bin"
  if [ "${_arg_dry_run}" != "on" ]; then
    mkdir -p "$bindir"
    # --- claudex: Claude Code interface driving a Codex/OpenAI model via proxy ---
    # Model remap (opus/sonnet/haiku slots) makes t3's picker show the real model,
    # not Claude Code's hardcoded Anthropic names.
    if [ "${_arg_with_claudex}" = "on" ]; then
      cat > "$bindir/claudex" <<CLXEOF
#!/usr/bin/env bash
# claudex — Claude Code interface driving ${_arg_claudex_model} via CLIProxyAPI.
# Source proxy env by ABSOLUTE path: t3 may run this with an isolated HOME.
_PROXY_ENV="/home/\$(id -un)/.ai-proxy.env"
[ -f "\$_PROXY_ENV" ] && . "\$_PROXY_ENV"
export ANTHROPIC_DEFAULT_OPUS_MODEL="\${CLAUDEX_OPUS_MODEL:-${_arg_claudex_model}}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="\${CLAUDEX_SONNET_MODEL:-${_arg_claudex_model}}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="\${CLAUDEX_HAIKU_MODEL:-${_arg_claudex_model}}"
export CLAUDE_CODE_SUBAGENT_MODEL="\${CLAUDEX_SUBAGENT_MODEL:-${_arg_claudex_model}}"
export CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1
export CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3
export ENABLE_TOOL_SEARCH=false
exec claude --model "\${CLAUDEX_MODEL:-${_arg_claudex_model}}" "\$@"
CLXEOF
      chmod +x "$bindir/claudex"
      _log_ok "claudex installed ($bindir/claudex) -> model ${_arg_claudex_model}"
    fi
    # --- glaude: Claude Code interface driving GLM via proxy ---
    if [ "${_arg_with_glaude}" = "on" ]; then
      cat > "$bindir/glaude" <<GLEOF
#!/usr/bin/env bash
# glaude — Claude Code interface driving ${_arg_glaude_model} via CLIProxyAPI.
# Source proxy env by ABSOLUTE path: t3 may run this with an isolated HOME.
_PROXY_ENV="/home/\$(id -un)/.ai-proxy.env"
[ -f "\$_PROXY_ENV" ] && . "\$_PROXY_ENV"
export ANTHROPIC_DEFAULT_OPUS_MODEL="\${GLAUDE_OPUS_MODEL:-${_arg_glaude_model}}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="\${GLAUDE_SONNET_MODEL:-${_arg_glaude_model}}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="\${GLAUDE_HAIKU_MODEL:-${_arg_glaude_model}}"
export CLAUDE_CODE_SUBAGENT_MODEL="\${GLAUDE_SUBAGENT_MODEL:-${_arg_glaude_model}}"
export ENABLE_TOOL_SEARCH=false
exec claude --model "\${GLAUDE_MODEL:-${_arg_glaude_model}}" "\$@"
GLEOF
      chmod +x "$bindir/glaude"
      _log_ok "glaude installed ($bindir/glaude) -> model ${_arg_glaude_model}"
    fi
  else
    [ "${_arg_with_claudex}" = "on" ] && printf '   [dry-run] create claudex wrapper -> %s\n' "$bindir/claudex"
    [ "${_arg_with_glaude}"  = "on" ] && printf '   [dry-run] create glaude wrapper -> %s\n' "$bindir/glaude"
  fi
  step_done claudex_glaude
}

step_grok() {
  [ "${_arg_with_grok}" = "on" ] || { _log_info "grok: skipped (--no-with-grok)"; return 0; }
  _log_step "grok CLI (x.ai build)"
  should_run grok || return 0
  # grok installs to ~/.grok/bin via the official install.sh (user-space, no sudo)
  if command -v grok >/dev/null 2>&1 || [ -x "$HOME/.grok/bin/grok" ]; then
    _log_ok "grok present"
    step_done grok; return 0
  fi
  _log_info "Installing grok via official x.ai install.sh"
  if [ "${_arg_dry_run}" != "on" ]; then
    sh -c 'curl -fsSL https://x.ai/cli/install.sh | bash' \
      || die "Failed to install grok (x.ai install.sh)"
    [ -x "$HOME/.grok/bin/grok" ] || die "grok binary not found at ~/.grok/bin/grok after install"
  else
    printf '   [dry-run] curl -fsSL https://x.ai/cli/install.sh | bash\n'
  fi
  # ensure ~/.grok/bin is on PATH (persist + export now)
  local line='export PATH="$HOME/.grok/bin:$PATH"'
  if [ "${_arg_dry_run}" != "on" ]; then
    for rc in "$HOME/.zshrc" "$HOME/.profile" "$HOME/.zshenv" "$HOME/.bashrc"; do
      touch "$rc"
      grep -qF '.grok/bin' "$rc" 2>/dev/null || printf '\n%s\n' "$line" >> "$rc"
    done
    export PATH="$HOME/.grok/bin:$PATH"
  fi
  _log_ok "grok installed (routes through proxy for xai models)"
  step_done grok
}

step_t3() {
  [ "${_arg_with_t3}" = "on" ] || { _log_info "t3: skipped (--no-with-t3)"; return 0; }
  _log_step "t3 harness"
  should_run t3 || return 0
  # needs build tools for node-pty — one helper, all distros
  local _bd; _bd="$(build_deps_pkgs)"
  [ -n "$_bd" ] && pm_install $_bd
  _npm_global t3 || die "Failed to install t3"
  command -v t3 >/dev/null 2>&1 || die "t3 not on PATH after install"
  # systemd user unit bound to LAN IP (or localhost if --bind-ip empty)
  local bind="${_arg_bind_ip:-127.0.0.1}"
  local udir="$HOME/.config/systemd/user"; run mkdir -p "$udir"
  if [ "${_arg_dry_run}" != "on" ]; then
    cat > "$udir/t3.service" <<T3EOF
[Unit]
Description=T3 Code server (headless)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=PATH=%h/.npm-global/bin:/usr/local/bin:/usr/bin:/bin
WorkingDirectory=%h
ExecStart=%h/.npm-global/bin/t3 serve --host ${bind} --port ${_arg_t3_port} --no-browser
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
T3EOF
  fi
  run systemctl --user daemon-reload
  run systemctl --user enable t3.service 2>/dev/null
  run systemctl --user restart t3.service 2>/dev/null
  # linger so it survives logout
  _log_info "Enabling linger (requires sudo) so services survive logout"
  run sudo loginctl enable-linger "$USER" 2>/dev/null || _log_warn "enable-linger failed — run: sudo loginctl enable-linger $USER"
  _log_ok "t3 installed + service enabled"
  _log_info "Pairing token: run 'journalctl --user -u t3' or 't3 auth pairing create' on the box"
  step_done t3
}

step_hermes() {
  [ "${_arg_with_hermes}" = "on" ] || { _log_info "hermes: skipped (--no-with-hermes)"; return 0; }
  _log_step "hermes-agent (docker compose)"
  should_run hermes || return 0
  local hdir="$HOME/hermes-agent"
  if [ ! -d "$hdir" ]; then
    _log_info "Cloning hermes-agent"
    run git clone https://github.com/NousResearch/hermes-agent.git "$hdir" \
      || die "Failed to clone hermes-agent"
  fi
  # NOTE: hermes reads config from ~/.hermes/config.yaml (mounted as /opt/data),
  # NOT from the repo dir. Write the proxy model block into the real config.
  local hhome="$HOME/.hermes"
  run mkdir -p "$hhome"
  if [ "${_arg_dry_run}" != "on" ]; then
    # bootstrap config if missing (minimal valid file), then set the model block
    if [ ! -f "$hhome/config.yaml" ]; then
      cat > "$hhome/config.yaml" <<'HCFG'
model:
  default: glm-5.2
  provider: custom
  base_url: http://127.0.0.1:8317/v1
terminal:
  backend: local
HCFG
    else
      # replace existing model block (up to the next top-level key)
      python3 - "$hhome/config.yaml" "$_arg_cliproxy_port" <<'PYEOF'
import re, sys
p, port = sys.argv[1], sys.argv[2]
s = open(p).read()
new = ("model:\n"
       "  default: glm-5.2\n"
       "  provider: custom\n"
       f"  base_url: http://127.0.0.1:{port}/v1\n")
s2, n = re.subn(r"model:.*?(?=\n[a-zA-Z])", new, s, count=1, flags=re.S)
if n == 0:
    s2 = new + s  # no model block found — prepend
open(p, "w").write(s2)
PYEOF
    fi
    # add OPENAI_API_KEY to ~/.hermes/.env (the secrets file hermes loads)
    touch "$hhome/.env"; chmod 600 "$hhome/.env"
    grep -q '^OPENAI_API_KEY=' "$hhome/.env" 2>/dev/null \
      || printf 'OPENAI_API_KEY=%s\n' "$_arg_cliproxy_key" >> "$hhome/.env"
  fi
  # inject OPENAI_API_KEY into the gateway compose environment so the container
  # process can authenticate to the proxy (compose interpolates from env)
  if [ "${_arg_dry_run}" != "on" ]; then
    python3 - "$hdir/docker-compose.yml" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
if "OPENAI_API_KEY=${OPENAI_API_KEY}" not in s:
    needle = "      - HERMES_GID=${HERMES_GID:-10000}\n"
    assert needle in s, "HERMES_GID env line not found in compose"
    s = s.replace(needle, needle + "      - OPENAI_API_KEY=${OPENAI_API_KEY}\n", 1)
    open(p, "w").write(s)
PYEOF
  fi
  _log_info "Building + starting hermes containers"
  # export the proxy key so docker compose can interpolate ${OPENAI_API_KEY}.
  # Use dock() so it gets sudo if the docker group isn't active this session yet.
  dock sh -c "cd '$hdir' && OPENAI_API_KEY='$_arg_cliproxy_key' HERMES_UID=\$(id -u) HERMES_GID=\$(id -g) docker compose up -d --build" \
    || die "docker compose up failed for hermes"
  _log_ok "hermes containers started"
  step_done hermes
}

step_verify() {
  if [ "${_arg_skip_verify}" = "on" ]; then
    _log_info "verify: skipped (--skip-verify, avoids token cost)"
    return 0
  fi
  _log_step "End-to-end verification"
  should_run verify || return 0
  local proxy="http://127.0.0.1:${_arg_cliproxy_port}"
  _log_info "Testing proxy /v1/models ..."
  if ! run sh -c "curl -fsS -m 10 '$proxy/v1/models' -H 'Authorization: Bearer ${_arg_cliproxy_key}' >/dev/null"; then
    _log_warn "proxy /v1/models not reachable — is cliproxyapi.service running? (systemctl --user status cliproxyapi)"
  else
    _log_ok "proxy responds"
  fi
  if command -v codex >/dev/null 2>&1; then
    _log_info "Testing codex -> proxy ..."
    run sh -c "cd /tmp && mkdir -p codex-verify && cd codex-verify && [ -d .git ] || git init -q && CLIPROXY_API_KEY='${_arg_cliproxy_key}' codex exec --skip-git-repo-check 'reply with the word OK' 2>&1 | grep -qi ok && echo 'codex: OK' || echo 'codex: FAIL'"
  fi
  if command -v opencode >/dev/null 2>&1; then
    _log_info "Testing opencode -> proxy ..."
    run sh -c "CLIPROXY_API_KEY='${_arg_cliproxy_key}' opencode run -m cliproxy/glm-5.2 'reply with the word OK' 2>&1 | grep -qi ok && echo 'opencode: OK' || echo 'opencode: FAIL'"
  fi
  if command -v claude >/dev/null 2>&1; then
    _log_info "Testing claude -> proxy ..."
    run sh -c "ANTHROPIC_BASE_URL='http://127.0.0.1:${_arg_cliproxy_port}' ANTHROPIC_API_KEY='${_arg_cliproxy_key}' claude -p 'reply with the word OK' --model glm-5.2 2>&1 | grep -qi ok && echo 'claude: OK' || echo 'claude: FAIL'"
  fi
  _log_ok "verification complete"
  step_done verify
}

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
print_summary() {
  _log_step "Summary"
  _log_ok "git: $(git --version 2>/dev/null | head -1 || echo 'check')"
  _log_ok "docker: $(docker --version 2>/dev/null | head -1 || echo 'check')"
  _log_ok "node: $(node --version 2>/dev/null || echo 'check')"
  [ "${_arg_with_zsh}" = "on" ]      && _log_ok "zsh: $(zsh --version 2>/dev/null | head -1 || echo 'check')"
  [ "${_arg_with_gh}" = "on" ]       && _log_ok "gh: $(gh --version 2>/dev/null | head -1 || echo 'check')"
  [ "${_arg_with_cliproxy}" = "on" ] && _log_ok "CLIProxyAPI: http://127.0.0.1:${_arg_cliproxy_port}"
  [ "${_arg_with_codex}" = "on" ]    && _log_ok "codex: $(codex --version 2>/dev/null || echo 'check')"
  [ "${_arg_with_claude}" = "on" ]   && _log_ok "claude: present"
  [ "${_arg_with_opencode}" = "on" ] && _log_ok "opencode: $(opencode --version 2>/dev/null || echo 'check')"
  [ "${_arg_with_claudex}" = "on" ]  && _log_ok "claudex: claude -> ${_arg_claudex_model}"
  [ "${_arg_with_glaude}" = "on" ]   && _log_ok "glaude: claude -> ${_arg_glaude_model}"
  if [ "${_arg_with_grok}" = "on" ]; then
    _grok_ver="$(grok --version 2>/dev/null | head -1)"
    _log_ok "grok: ${_grok_ver:-$HOME/.grok/bin/grok}"
  fi
  [ "${_arg_with_t3}" = "on" ]       && _log_ok "t3: http://${_arg_bind_ip:-127.0.0.1}:${_arg_t3_port}/pair (token via 't3 auth pairing create')"
  [ "${_arg_with_hermes}" = "on" ]   && _log_ok "hermes: docker compose up"
  _log_info "State file: $_arg_state_file"
  _log_info "Proxy key: ${_arg_cliproxy_key:0:8}... (full in $(_state_dir)/.secrets.env)"
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
main() {
  detect_distro
  ensure_prereqs        # curl/ca-certificates/tar — everything else needs these
  init_state
  ensure_secrets
  parse_providers

  step_git
  step_docker
  step_node
  step_zsh
  step_gh
  # cliproxy must come before agents (agents wire to it)
  step_cliproxy
  step_agents
  # wrappers depend on claude being installed + proxy env present
  step_claudex_glaude
  step_grok
  step_t3
  step_hermes
  step_verify

  print_summary
  _log_ok "Done."
}

main "$@"
