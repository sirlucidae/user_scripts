#!/bin/bash

  ####                     ####
####  Default User Settings  ####
  ####                     ####

# Threads - requires env_parallel, in threaded mode setting both to "0" calls env_parallel without a jobs option, which should use all available threads
threads_used="0"                   # maximum number of threads to use
threads_unused="0"                 # number of threads to leave unused

# SoX command construction: $sox_bits and $sox_dither are unset for 24 bit outputs, and $sox_rate is unset for 24/44 and 24/48 sources
# $> sox $sox_pre_input INPUT.flac $sox_pre_output $sox_bits OUTPUT.flac $sox_rate RATE $sox_dither

# 'global' sox options, followed by any 'format options' for the input file
# /currently/, text/status output is only shown if/when sox has a non-zero exit status
sox_pre_input="-G -R -V2"

# 'format options' applicable to the output file, excluding '-b' which follows $sox_pre_output, and is set automatically
sox_pre_output=""

# SoX dither                       # "dither" is recommended, but noise-shaped dither ("dither -s") may help with sources for which -G/--guard is
sox_dither="dither"                # not sufficient to prevent clipping, and any other valid dither effect command may be set here

# SoX rate
sox_rate="rate -v -L"              # Set any valid rate effect command for SoX here, "rate -v -L" is recommended

# FLAC Padding - set to "0" to disable adding padding to output files - NB: without padding tag edits require completely rewriting the entire flac file
flac_padding="4096"                # length in bytes of the padding block added by metaflac to converted files (+4 more bytes for padding block header)

# Automator users on MacOS may have issues where depedencies installed via Homebrew, like sox, are not discoverable by default in the environment which Automator runs the script.
# The location for Homebrew binaries currently defaults to a "bin" folder found in either /usr/local (Intel Macs), or /opt/homebrew (Apple Silicon Macs). With Homebrew installed you
# should be able to test if either of these is the case by running "brew --prefix" in Terminal, to print the location applicable on your system. If either default value is returned,
# leave homebrew_bin empty/unset below (or use the -W option if you want to keep a non-standard default set here), and your Homebrew programs should be successfully detected. If you
# want to use Homebrew programs in a non-standard prefix (which is not recommended by the Homebrew project for normal users), you can set homebrew_bin below with the path to the
# applicable "bin" folder, or provide the folder as the argument to the -w option.
homebrew_bin=""                    # leave empty/unset to check both default Homebrew prefix locations

# env_parallel and env_parallel.bash overrides - specify absolute path(s) here if either file is not detected
env_parallel_command="env_parallel"    # default: "env_parallel"       --- both       must    detected    use          threads
env_parallel_bash="env_parallel.bash"  # default: "env_parallel.bash"  ---      files      be          to     multiple

# custom output directory name
custom_outdir="defaults"           # use "defaults" for script defaults, or set name to use for all output folders

# Script Features - setting the value for options below to "1" enables them, any other text (or lack thereof) between the double-quotes disables
threads_off="0"                    # use single threaded mode

recurse_all_subdirs="1"            # find/use as potential sources, all flac files at any tree depth under any directories provided as command line arguments
                                   # when disabled only flac files found in the specific directories provided as arguments, and their immediate subdirectories, are used

embed_artwork="1"                  # embed in target flac(s), any embedded artwork found in corresponding source flac(s)

use_24_44_and_24_48_input="0"      # output 16/44 and 16/48 from 24/44 and 24/48 sources
use_24_88_and_24_96_output="0"     # output 24/88.2 and 24/96 from 24/176.4 and 24/192 sources

use_SOURCE_FFP_tag="1"             # create a tag containing the md5sum for the source file's decompressed audio stream, AKA the FLAC Fingerprint
use_SOURCE_SPECS_tag="1"           # create a tag detailing the source file's bit depth and sample rate
use_SOX_COMMAND_tag="1"            # create a tag detailing the SoX command used to convert the file

use_progress_bar="1"               # use GNU parallel's progress bar (no effect in single thread mode)

verbose_output="1"                 # print per-file conversion details to stdout during operation
sox_emits="1"                      # emit any output from sox to stdout & stderr --> depends on verbose_output="1" / --info / -i

  ####                       ####
####  End of Default Settings  ####
  ####                       ####


# TO DO #
# -remove dependency on env_parallel
# -delete sources on success (??)
# fix potential race condition when using 24-bit outputs (on subsequent runs former targets can become sources /and/ targets)


_print_usage() {
	command -v cat >/dev/null 2>&1 || { _error "'cat' not found (?!), no '--help' for you!" ;return 1 ; }
	cat <<EOF
${bold}USAGE:${default}

$0 [OPTION [ARGUMENT]]... [--] FILE_OR_FOLDER [FILE_OR_FOLDER]...


${bold}OPTIONS:${default}

${bold}Script:${default}
-h, -H, --help                    Print this help text and exit.
--                                End of options. Following arguments taken as files/folders for conversion.

-e, --8896                        Output 24/88.2 and 24/96 from 24/176.4 and 24/192 sources.
-E, --no-8896                     Don't output 24/88.2 and 24/96 from 24/176.4 and 24/192 (but do output 16/44 and 16/48).

-f, --4448                        Output 16/44 and 16/48 from 24/44 and 24/48 sources.
-F, --no-4448                     Don't use 24/44 and 24/48 sources.

-i, --info                        Print each filename and some basic status information while running, and errors.
-I, --info-off                    Only print start/end messages (numbers of source/target files, overall success/failure), and errors.

-n "ARG", --env-parallel "ARG"        Use the name (or absolute path) "ARG" for "env_parallel". Currently set to: "$env_parallel_command".
-N "ARG", --env-parallel-bash "ARG"   Use the name (or absolute path) "ARG" for "env_parallel.bash". Currently set to: "$env_parallel_bash".

-o, --threads-on                  Use env_parallel for multi-threaded operation.
-O, --threads-off                 Don't use env_parallel, run in single-threaded mode.

-t ARG, --threads ARG             Number of threads to use. Disables "-T / --unthreads". Set to "0" to use all available threads.
-T ARG, --unthreads ARG           Number of threads to leave unused. Disables "-t / --threads". Set to "0" to use all available threads.

-u, --recurse                     Find/use as potential sources, all flac files at any tree depth under any directories provided as command line arguments.
-U, --no-recurse                  Only flac files found in the specific directories provided as arguments, and their immediate subdirectories, are used.

-w "ARG", --homebrew-bin "ARG"    Set the location of your Homebrew binaries for non-default Homebrew prefixes, eg: "/Users/you/homebrew/bin"
-W, --default-homebrew            Check for Homebrew binaries in the default locations for both Intel and Apple Silicon Macs (script's default)

-z, --custom-outdir "ARG"         Set name for all output folders to "ARG".
-Z, --default-outdir              Use the default target-rate-based output folder naming.


${bold}metaflac:${default}
-a, --artwork                     Embed in target flac(s), any artwork embedded in source flac(s)
-A, --no-artwork                  Do not embed in target flac(s), any artwork embedded in source flac(s)

-c, --command-tag                 Tag output with the SoX command (not including file paths/names) used to convert the file.
-C, --no-command-tag              Do not tag output with the SoX command used to convert the file.

-m, --ffp-tag                     Tag output with the source file's flac fingerprint.
-M, --no-ffp-tag                  Do not tag output with the source file's flac fingerprint.

-p ARG, --padding ARG             Number of bytes to use for FLAC padding. Set to 0 to disable adding any padding (not recommended).

-s, --source-tag                  Tag output with the source file's bit depth and sample rate.
-S, --no-source-tag               Do not tag output with the source file's bit depth and sample rate.


${bold}GNU Parallel:${default}
-b, --progress-bar                Use GNU Parallel's progress bar. No effect in single thread mode.
-B, --no-progress-bar             Don't use GNU Parallel's progress bar.


${bold}SoX:${default}
-d "ARG", --dither "ARG"          Dither effect command for SoX, arguments with spaces should be quoted.
-D, --default-dither              Sets dither command to "dither".

-r "ARG", --rate "ARG"            Rate effect command for SoX, arguments with spaces should be quoted.
-R, --default-rate                Sets rate command to "rate -v -L" (very high quality, linear phase response).

-v ARG, --sox-verbosity ARG       SoX's -V option, must be set with a number between 0 and 4.

EOF
}

version="0.9.2"

# colourful printf       # tput is not always present
    red=$'\033[0;31m'    # "$( tput setaf 1 )"
  green=$'\033[0;32m'    # "$( tput setaf 2  )"
 orange=$'\033[0;33m'    # "$( tput setaf 3 )"
   bold=$'\033[1m'       #     tput srg1 # ??
default=$'\033[0m'       # "$( tput sgr0 )"

_message() {
	case "$1" in
		-n) shift; printf '%s\n'   "$@" ;;
		-N) shift; printf '%s\n\n' "$@" ;;
		 *)        printf '%s'     "$@" ;;
	esac
}
_warning() { printf >&2 '%sWARNING%s: %s\n\n' "${orange}" "${default}" "$@" ; } # NB: these redirects to stderr seem to screw with placement among other messages when using
_error()   { printf >&2 '%sERROR%s: %s\n\n'   "${red}"    "${default}" "$@" ; } #     parallel/env_parallel... occam's razor: env_parallel emits all stdout first, then all stderr. hah!
_st_or_quit() { unset quitnow # "local quitnow" instead? same difference?
				read -n 1 -erp "Press Q/q/A/a to abort, or any other character to continue in single threaded mode: " quitnow
				_message -n
				[[ $quitnow == [QqAa] ]] && { _message -N "Aborting." ;exit 1 ; }
			  }

_message -n

# runtime options -- letters left: gG jJ kK lL qQ xX yY
while true ;do
	case "$1" in
		-a|--artwork)
			embed_artwork="1"
			shift
			;;
		-A|--no-artwork)
			embed_artwork="0"
			shift
			;;
		-b|--progress-bar)
			use_progress_bar="1"
			shift
			;;
		-B|--no-progress-bar)
			use_progress_bar="0"
			shift
			;;
		-c|--command-tag)
			use_SOX_COMMAND_tag="1"
			shift
			;;
		-C|--no-command-tag)
			use_SOX_COMMAND_tag="0"
			shift
			;;
		-d|--dither)
			_warning "Validity of the dither effect command is your responsibility. Arguments with spaces should be quoted."
			sox_dither="$2"
			shift 2
			;;
		-D|--default-dither)
			sox_dither="dither"
			shift
			;;
		-e|--8896)
			use_24_88_and_24_96_output="1"
			shift
			;;
		-E|--no-8896)
			use_24_88_and_24_96_output="0"
			shift
			;;
		-f|--4448)
			use_24_44_and_24_48_input="1"
			shift
			;;
		-F|--no-4448)
			use_24_44_and_24_48_input="0"
			shift
			;;
		-h|-H|--help)
			_print_usage ;exit
			;;
		-i|--info)
			verbose_output="1"
			shift
			;;
		-I|--info-off)
			verbose_output="0"
			shift
			;;
		-m|--ffp-tag)
			use_SOURCE_FFP_tag="1"
			shift
			;;
		-M|--no-ffp-tag)
			use_SOURCE_FFP_tag="0"
			shift
			;;
		-n|--env-parallel)
			env_parallel_command="$2"
			shift 2
			;;
		-N|--env-parallel-bash)
			env_parallel_bash="$2"
			shift 2
			;;
		-o|--threads-on)
			threads_off="0"
			shift
			;;
		-O|--threads-off)
			threads_off="1"
			shift
			;;
		-p|--padding)
			flac_padding="$2"
			shift 2
			;;
		-P|--print-defaults) # ?? worth figuring out having all these defaults in an assoc. array and not using "${!var}" ?? not as much as other things probably
			printf '%sCurrent Default User Settings%s:\n' "${bold}" "${default}"
			for var in threads_used threads_unused sox_verbosity_level sox_dither sox_rate flac_padding homebrew_bin env_parallel_command env_parallel_bash \
									threads_off recurse_all_subdirs	use_24_44_and_24_48_input use_24_88_and_24_96_output use_SOURCE_FFP_tag \
									use_SOURCE_SPECS_tag use_SOX_COMMAND_tag use_progress_bar verbose_output ;do
				printf '%30s %s\n' "${var}:" "${!var}" # https://unix.stackexchange.com/a/222586, https://unix.stackexchange.com/a/631737
			done
			printf '\n'
			exit
			;;
		-r|--rate)
			_warning "Validity of the rate effect command is your responsibility. Arguments with spaces should be quoted."
			sox_rate="$2"
			shift 2
			;;
		-R|--default-rate)
			sox_rate="rate -v -L"
			shift
			;;
		-s|--source-tag)
			use_SOURCE_SPECS_tag="1"
			shift
			;;
		-S|--no-source-tag)
			use_SOURCE_SPECS_tag="0"
			shift
			;;
		-t|--threads)
			threads_used="$2" ;threads_unused="0"
			shift 2
			;;
		-T|--unthreads)
			threads_unused="$2" ;threads_used="0"
			shift 2
			;;
		-u|--recurse)
			recurse_all_subdirs="1"
			shift
			;;
		-U|--no-recurse)
			recurse_all_subdirs="0"
			shift
			;;
#		-v|--sox-verbosity)
#			sox_verbosity_level="$2"
#			shift 2
#			;;
		--version)
			printf 'downsampler-threaded v%s\n' "$version"
			exit 0
			;;
		-w|--homebrew-bin)
			homebrew_bin="$2"
			shift 2
			;;
		-W|--default-homebrew)
			homebrew_bin=""
			shift
			;;
		-z|--custom-outdir)
			custom_outdir="$2"
			shift 2
			;;
		-Z|--default-outdir)
			custom_outdir="defaults"
			shift
			;;
		--)
			break
			;;
		-?*)
			_error "Unknown option '$1'." ;_print_usage ;exit 1
			;;
		*)
			break
			;;

	esac
done

# argument(s) required
[[ $# -ge "1" ]] || { _error "Nothing to do, please specify at least one file or folder." ;_print_usage ;exit 1 ; }

# Bash required
[[ -n $BASH_VERSION ]] || { _error "Interpreter does not appear to be Bash, aborting." ;exit 1 ; }

# validate threads
if [[ $threads_off != "1" ]] ;then
	[[ $threads_used   != *[!0123456789]* ]] || { _error "Argument for '-t / --threads / threads_used' must be zero or a positive integer."     ;exit 1 ; }
	[[ $threads_unused != *[!0123456789]* ]] || { _error "Argument for '-T / --unthreads / threads_unused' must be zero or a positive integer." ;exit 1 ; }
fi

# validate flac padding
if [[ $flac_padding != *[!0123456789]* ]] ;then
	if [[ $flac_padding -ge "1" ]] ;then
		[[ $flac_padding -le "512" ]]  && _warning "Using only $flac_padding bytes for FLAC padding. Maybe this is enough for your needs, but it's not very much."
		[[ $flac_padding -gt "8192" ]] && _warning "Using more than 8KB for FLAC padding. Maybe your needs require that much, but it's quite a lot."
	fi
else
	_error "Argument for '-p / --padding / flac_padding' must be zero or a positive integer." ;exit 1
fi

# validate sox verbosity
#[[ $sox_verbosity_level == [01234] ]] || { _error "Argument for '-v / --sox-verbosity / sox_verbosity_level' must be an integer between 0 and 4." ;exit 1 ; }

# ctrl+c exits script, not just sox/whatever --- does this work as expected...?? here's guessing if/when it doesn't, it's a parallel/environment issue
trap "exit 1" INT

# dependencies
# Automator defaults to ignoring Homebrew (its PATH does not include /usr/local/bin or /opt/*/bin)
if [[ -z "$homebrew_bin" ]] ;then
	if [[ -x /usr/local/bin/brew ]] ;then
		homebrew_bin="/usr/local/bin"
	elif [[ -x /opt/homebrew/bin/brew ]] ;then
		homebrew_bin="/opt/homebrew/bin"
	fi
else
	[[ -x "$homebrew_bin"/brew ]] || {
		printf >&2 '%sERROR%s: "homebrew_bin" was set but "brew" command was not found in set location.\n       Try using -W to check both default locations, or provide the correct non-standard path as the argument to -w.\n       See comments above the "homebrew_bin" option at the top of the script for more details.\n\n' "$red" "$default"
		exit 1
	}
fi
[[ -n "$homebrew_bin" && $PATH != *"$homebrew_bin"* ]] && PATH=$PATH:"$homebrew_bin" # drop any potential user-supplied trailing slashes from *"$homebrew_bin"* here?
command -v basename >/dev/null 2>&1 || { _error "'basename' not found, aborting." ;exit 1 ; }
command -v dirname  >/dev/null 2>&1 || { _error "'dirname' not found, aborting."  ;exit 1 ; }
command -v sox      >/dev/null 2>&1 || { _error "'sox' not found, aborting."      ;exit 1 ; }

# recommends
if [[ $flac_padding != "0" || $use_SOURCE_SPECS_tag == "1" || $use_SOX_COMMAND_tag == "1" || $use_SOURCE_FFP_tag == "1" || $embed_artwork == "1" ]] ;then
	command -v metaflac >/dev/null 2>&1 || { _error "'metaflac' not found, aborting." ;exit 1 ; }
	metaflac_enabled="1"
fi

if [[ $threads_off == "1" ]] ;then
	_message -n "${orange}Running in single thread mode.${default}."
elif command -v "$env_parallel_command" >/dev/null 2>&1 && command -v "$env_parallel_bash" >/dev/null 2>&1 ;then
	[[ $use_progress_bar == "1" ]] && parallel_progress_bar[0]="--bar"
	if [[ $threads_unused -gt "0" && $threads_used -gt "0" ]] ;then
		_warning "The options 'threads_used' and 'threads_unused' are mutually exclusive."
		_st_or_quit
		threads_off="1"
	else
		[[ $threads_used -gt "0" ]]   && paralleljobs[0]="-j $threads_used"
		[[ $threads_unused -gt "0" ]] && paralleljobs[0]="-j -$threads_unused"
	fi
else
	command -v "$env_parallel_command" >/dev/null 2>&1 || { _error "'env_parallel' not found - looking for this name/path: '$env_parallel_command'"
															_message -N "Try using '-n / --env-parallel' or an absolute path for 'env_parallel' in the 'Default User Settings' section."
															envparfail="1" ; }
	command -v "$env_parallel_bash" >/dev/null 2>&1 || { _error "'env_parallel.bash' not found - looking for this name/path: '$env_parallel_bash'"
														 _message -N "Try using '-N / --env-parallel-bash' or an absolute path for 'env_parallel_bash' in the 'Default User Settings' section."
														 envparfail="1" ; }
	[[ $envparfail == "1" ]] && _st_or_quit
	_message -n "${orange}Running in single thread mode${default}."
	threads_off="1"
fi

if command -v realpath >/dev/null 2>&1 ;then realpath="realpath --" ;elif command -v grealpath >/dev/null 2>&1 ;then realpath="grealpath --"
else
	_absolute_path() { ( cd -P -- "$( dirname -- "$1" )" 2>/dev/null && printf '%s/%s\n' "$PWD" "$( basename -- "$1" )" ) ; }
	realpath="_absolute_path"
fi

# handle file/folder arguments
user_args=( "$@" )
if [[ $recurse_all_subdirs == "1" ]] ;then
	if shopt -s globstar nullglob >/dev/null 2>&1 ;then
		for arg in "${user_args[@]}" ;do
			[[ -d $arg ]] && user_args+=( "$arg"/**/*.[Ff][Ll][Aa][Cc] )
		done
		shopt -u globstar nullglob
	elif command -v find >/dev/null 2>&1 ;then # is there a better test to use here that can determine if the 'find' command found has the -print0 option?
		for arg in "${user_args[@]}" ;do
			[[ -d $arg ]] && {
				#readarray -d '' dir_flacs < <( find "$arg" -type f -iname "*.flac" -print0 ) # not much of a bash<4 fallback if it needs bash 4
				dir_flacs=()                 # https://stackoverflow.com/a/23357277
				while IFS= read -r -d '' ;do # https://unix.stackexchange.com/questions/209123/understanding-ifs-read-r-line -- it says "understanding" right there in the title
					dir_flacs+=( "$REPLY" )
				done < <( find "$arg" -type f -iname "*.flac" -print0 )
				user_args+=( "${dir_flacs[@]}" )
			}
		done
	else
		_error "Could not enable globstar (Bash 4+), and could not find 'find' command, aborting."
		_message -N "If all else fails, try disabling 'recurse_all_subdirs' with '-U / --no-recurse'."
		exit 1
	fi
else
	for arg in "${user_args[@]}" ;do
		if [[ -d $arg ]] ; then
			user_args+=( "$arg"/*.[Ff][Ll][Aa][Cc] )
			for subdir in "$arg"/* ;do
				if [[ -d $subdir ]] ;then
					user_args+=( "$subdir"/*.[Ff][Ll][Aa][Cc] )
				fi
			done
		fi
	done
fi

# get absolute paths, drop any duplicates
for arg in "${user_args[@]}" ;do
	absolute_args+=( "$( $realpath "$arg" )" )
done
#readarray -t unique_args < <( printf '%s\n' "${absolute_args[@]}" | sort -u  )
while IFS= read -r -d '' ;do
	unique_args+=( "$REPLY" )
done < <( printf '%s\0' "${absolute_args[@]}" |sort -zu )

_message "Reading input file(s)... "

# just the flacs, just the 24 bit flacs
for arg in "${unique_args[@]}" ;do
	[[ ! -d $arg && $arg == *.[Ff][Ll][Aa][Cc] ]] && [[ $( sox --i -b -- "$arg" ) -eq "24" ]] && absolute_flac_names+=( "$arg" )
done

# candidate flacs must exist
[[ ${#absolute_flac_names[@]} -ge "1" ]] || { _error "No candidate FLAC files found, aborting." ;exit 1 ; }

# source data
for index in "${!absolute_flac_names[@]}" ;do
	flac_filenames[$index]="$( basename -- "${absolute_flac_names[$index]}" )"
	absolute_flac_dirs[$index]="$( dirname -- "${absolute_flac_names[$index]}" )"
	flac_sample_rates[$index]="$( sox --i -r -- "${absolute_flac_names[$index]}" )"
done

_message "Found ${#absolute_flac_names[@]} candidate FLAC file(s). Configuring output... "

# target data
for index in "${!absolute_flac_names[@]}" ;do

	target_bits_opt[$index]="-b 16"
	target_dither_cmd[$index]="$sox_dither"
	case ${flac_sample_rates[$index]} in
		44100|48000)
			((use_24_44_and_24_48_input)) || continue
			target_sample_rates[$index]=""
			target_rate_cmd[$index]=""
			target_folders[$index]="${absolute_flac_dirs[$index]}/unresampled-16bit"
			;;
		88200)
			target_sample_rates[$index]="44100"
			target_folders[$index]="${absolute_flac_dirs[$index]}/resampled-16-44"
			;;
		96000)
			target_sample_rates[$index]="48000"
			target_folders[$index]="${absolute_flac_dirs[$index]}/resampled-16-48"
			;;
		176400)
			if ((use_24_88_and_24_96_output)) ;then
				target_bits_opt[$index]=""
				target_sample_rates[$index]="88200"
				target_dither_cmd[$index]=""
				target_folders[$index]="${absolute_flac_dirs[$index]}/resampled-24-88"
			else
				target_sample_rates[$index]="44100"
				target_folders[$index]="${absolute_flac_dirs[$index]}/resampled-16-44"
			fi
			;;
		192000)
			if ((use_24_88_and_24_96_output)) ;then
				target_bits_opt[$index]=""
				target_sample_rates[$index]="96000"
				target_dither_cmd[$index]=""
				target_folders[$index]="${absolute_flac_dirs[$index]}/resampled-24-96"
			else
				target_sample_rates[$index]="48000"
				target_folders[$index]="${absolute_flac_dirs[$index]}/resampled-16-48"
			fi
			;;
		*)
			continue
			;;
	esac
	[[ -n ${target_sample_rates[$index]} ]] && target_rate_cmd[$index]="${sox_rate} ${target_sample_rates[$index]}"

	# don't set target_flacs[$index] unless the flac at this index has already matched one of the rules above
	if [[ -n ${target_folders[$index]} ]] ;then
		[[ -n $custom_outdir && $custom_outdir != "defaults" ]] && target_folders[$index]="${absolute_flac_dirs[$index]}/${custom_outdir[0]}"
		target_flacs[$index]="${target_folders[$index]}/${flac_filenames[$index]}"
	fi
done

# target flacs must exist
[[ ${#target_flacs[@]} -ge "1" ]] || { _error "No targets for conversion, aborting." ;exit 1 ; }

# are any target flacs ALSO source flacs??
# do any targets already exist??

# where all the output-producing and output-modifying actions happen
_execute() {
	index="$1"
	[[ $verbose_output == "1" ]] && {
		local bits="${target_bits_opt[$index]#-b }"
		_message -n " ${target_flacs[$index]}:"
		printf '   %sInput%s: 24 / %-9s %sOutput%s: %s / %-9s %sStatus%s: ' \
			   "${bold}" "${default}" "${flac_sample_rates[$index]}" \
			   "${bold}" "${default}" "${bits:-24}" "${target_sample_rates[$index]:-${flac_sample_rates[$index]}}" \
			   "${bold}" "${default}"
	}
	[[ ! -d ${target_folders[$index]} ]] && mkdir -p -- "${target_folders[$index]}"
	#if outerr="$( sox -V"${sox_verbosity_level[0]}" "${absolute_flac_names[$index]}" -R -G ${target_bits_opt[$index]} "${target_flacs[$index]}" ${target_rate_cmd[$index]} ${target_dither_cmd[$index]} 2>&1 )" ;then
	if outerr="$( sox $sox_pre_input "${absolute_flac_names[$index]}" $sox_pre_output ${target_bits_opt[$index]} "${target_flacs[$index]}" ${target_rate_cmd[$index]} ${target_dither_cmd[$index]} 2>&1 )" ;then

		[[ $verbose_output == "1" ]] && {
			_message "${green}Success${default}!     "

			# awk indents (each line of) $soxout, but in some modes, sox uses a carriage return on a
			# repeatedly-emitted (and newline-omitted) single line of its per-file stdout (an ongoing status/progress display)
			# sed replaces each carriage return with a carriage return followed by the same number of spaces awk indents all the other lines to
			[ -n "$outerr" ] && [ "$sox_emits" = "1" ] &&
				printf -v sox_outerr -- '      %s*%s sox had this output:\n      %s-----%s\n%s\n      %s-----%s\n\n' \
					   "$orange" "$default" "$bold" "$default" "$( printf -- '%s' "$outerr" |awk -- '{ print "      " $0 }' |sed -- 's/\r/\r      /g' )" "$bold" "$default"

			[[ $metaflac_enabled == "1" ]] && _message "${bold}metaflac${default}: "
		}

		[[ $metaflac_enabled == "1" ]] && {

			_metaflac_failure() {
				if [[ $verbose_output == "1" ]] ;then
					printf '%sFAILED%s! to add %s\n\n      %s*%s Aborting any further tasks for this file.\n      %s*%s metaflac failed with this output:\n      %s-----%s\n%s\n      %s-----%s\n\n' \
						   "${red}" "${default}" "$1" "${red}" "${default}" "${red}" "${default}" "${bold}" "${default}" "$( printf '%s' "$outerr" | awk -- '{ print "      " $0 }' )" "${bold}" "${default}"
				else
					printf '%sERROR%s! metaflac had non-zero exit status adding %s to target %s%s%s.\n %s*%s Aborting any further tasks for this file.\n %s*%s metaflac failed with this output:\n %s-----%s\n%s\n %s-----%s\n\n\n\n' \
						   "${red}" "${default}" "$1" "${bold}" "${target_flacs[$index]}" "${default}" "${red}" "${default}" "${red}" "${default}" "${bold}" "${default}" "${outerr}" "${bold}" "${default}"
				fi
			}

			[[ $embed_artwork == "1" ]] && {
				local artwork="${target_flacs[$index]}.metaflac.img"
				metaflac --export-picture-to="$artwork" -- "${absolute_flac_names[$index]}" >/dev/null 2>&1 && # export failure is the best(? good even?) test for artwork existence? so far...
					if outerr="$( metaflac --import-picture-from="$artwork" -- "${target_flacs[$index]}" 2>&1 )" ;then
					#if ! [[ ${absolute_flac_names[$index]} == *"03-foo.flac" ]] ;then
						rm -- "$artwork"
					else
						_metaflac_failure 'embedded artwork'
						metaflac_failures[$index]="1"
						imperfect_indexes[$index]="1"
						[[ -n "$sox_outerr" ]] && [ "$sox_emits" = "1" ] && printf '%s' "$sox_outerr"
						return 1
					fi
			}

			[[ $flac_padding != "0" ]] && {
				if ! outerr="$( metaflac --add-padding="$flac_padding" -- "${target_flacs[$index]}" 2>&1 )" ;then
					_metaflac_failure 'padding'
					metaflac_failures[$index]="1" # these failure arrays sadly are not usable when env_parallel runs this function - gnu parallel has "setenv" but it's
					imperfect_indexes[$index]="1" # not in every version, and it's not clear that it would help when not using parallel
					[[ -n "$sox_outerr" ]] && [ "$sox_emits" = "1" ] && printf '%s' "$sox_outerr"
					return 1                      # ?? exit status seems like the only "var" we can send/export out of env_parallel's environment and use in the script's environment ??
				fi                                # final thought: can still use these arrays inside the function to decide whether to delete successfully converted files!
			}
			[[ $use_SOX_COMMAND_tag == "1" ]] && {
				#if ! outerr="$( metaflac --set-tag=SOX_COMMAND="sox input.flac -R -G ${target_bits_opt[$index]} output.flac ${target_rate_cmd[$index]} ${target_dither_cmd[$index]}" -- "${target_flacs[$index]}" 2>&1 )" ;then
				if ! outerr="$( metaflac --set-tag=SOX_COMMAND="sox $sox_pre_input INPUT.flac $sox_pre_output ${target_bits_opt[$index]} OUTPUT.flac ${target_rate_cmd[$index]} ${target_dither_cmd[$index]}" -- "${target_flacs[$index]}" 2>&1 )" ;then
					_metaflac_failure 'SOX_COMMAND tag'
					metaflac_failures[$index]="1"
					imperfect_indexes[$index]="1"
					[[ -n "$sox_outerr" ]] && [ "$sox_emits" = "1" ] && printf '%s' "$sox_outerr"
					return 1
				fi
			}
			[[ $use_SOURCE_SPECS_tag == "1" ]] && {
				if ! outerr="$( metaflac --set-tag=SOURCE_SPECS="24 bit, ${flac_sample_rates[$index]} Hz" -- "${target_flacs[$index]}" 2>&1 )" ;then
					_metaflac_failure 'SOURCE_SPECS tag'
					metaflac_failures[$index]="1"
					imperfect_indexes[$index]="1"
					[[ -n "$sox_outerr" ]] && [ "$sox_emits" = "1" ] && printf '%s' "$sox_outerr"
					return 1
				fi
			}
			[[ $use_SOURCE_FFP_tag == "1" ]] && {
				if ! outerr="$( metaflac --set-tag=SOURCE_FFP="$( metaflac --show-md5sum "${absolute_flac_names[$index]}" )" -- "${target_flacs[$index]}" 2>&1 )" ;then
					_metaflac_failure 'SOURCE_FFP tag'
					metaflac_failures[$index]="1"
					imperfect_indexes[$index]="1"
					[[ -n "$sox_outerr" ]] && [ "$sox_emits" = "1" ] && printf '%s' "$sox_outerr"
					return 1
				fi
			}

			# really needed to have '-z $metaflac_failures' ? is return not called every time it's non-zero?
			[[ $verbose_output == "1" && -z "${metaflac_failures[$index]}" ]] && _message -N "${green}Done${default}!"
			[[ -n "$sox_outerr" ]] && [ "$sox_emits" = "1" ] && printf '%s' "$sox_outerr"
		}

		# delete successfully converted source files here! ... with your own code for now, sorry. I'll get there eventually I _swear_ !
		# [[ $source_deletion_enabled == "1" && -z ${metaflac_failures[$index]} ]] && { rm -f -- "${absolute_flac_names[$index]}" ; } # or something
		# 'rmdir' later, outside this 'if' (? tracking succcess/fail in env_parallel? ... or?)  ... or just "rmdir "${target_folders[$index]}" >/dev/null 2>&1" right here, on every index, yay rmdir

		return 0
	else
		if [[ $verbose_output == "1" ]] ;then
			printf '%sFAILED%s!\n   %s*%s Aborting any follow-up tasks for this file.\n   %s*%s sox failed with this output:\n   %s-----%s\n%s\n   %s-----%s\n\n' \
				   "${red}" "${default}" "${red}" "${default}" "${red}" "${default}" "${bold}" "${default}" "${outerr}" "${bold}" "${default}"
		else
			printf '%sERROR%s! sox had non-zero exit status converting target %s%s%s.\n %s*%s Aborting any follow-up tasks for this file.\n %s*%s sox failed with this output:\n %s-----%s\n%s\n %s-----%s\n\n' \
				   "${red}" "${default}" "${bold}" "${target_flacs[$index]}" "${default}" "${red}" "${default}" "${red}" "${default}"  "${bold}" "${default}" "${outerr}" "${bold}" "${default}"
		fi
		sox_failures[$index]="1"
		imperfect_indexes[$index]="1"
		return 1
	fi
}

# use the _execute function, with threads, or without, to output ${target_flacs[@]}
if [[ $threads_off == "1" ]] ;then
	_message -N "Converting ${#target_flacs[@]} target(s) with SoX..."
	for index in "${!target_flacs[@]}" ;do
		_execute "$index"
	done
	
	if [[ -z ${imperfect_indexes[*]} ]] ;then # appease shellcheck/SC2199 by using [*] instead of [@]
		_message "${green}Done${default}! "
		_message -N "Converted ${#target_flacs[@]} target(s) with no apparent failures."
	elif [[ ${#imperfect_indexes[@]} -eq ${#target_flacs[@]} ]] ;then
		_message "${red}Done.${default} "
		_error "TOTAL FAILURE: EVERY TARGET failed at least 1 of their tasks!"
	else
		_message "${orange}Done.${default} "
		_error "PARTIAL FAILURE: At least 1 task failed for ${#imperfect_indexes[@]} (out of ${#target_flacs[@]}) target(s)!"
	fi

	if [[ $verbose_output != "1" && -n ${imperfect_indexes[*]} ]] ;then # this non-verbose mode failed file listing has been tacked on at the last minute... works??
		[[ -n ${sox_failures[*]} ]]      && { _message -n "SoX failures:"      ;for index in "${!sox_failures[@]}"      ;do printf '  %s\n' "${target_flacs[$index]}" ;done ; }
		[[ -n ${metaflac_failures[*]} ]] && { _message -n "metaflac failures:" ;for index in "${!metaflac_failures[@]}" ;do printf '  %s\n' "${target_flacs[$index]}" ;done ; }
	fi
else
	_message -N "Converting ${#target_flacs[@]} target(s) with SoX and env_parallel..."
	source "$env_parallel_bash"
	
	# obvious(?) line groups... (0: env_parallel) 1: functions   2: source data   3: target data   4: sox options   5: metaflac vars   6: script vars   7: colour vars
	"$env_parallel_command" \
		--env _execute --env _message --env _error \
		--env absolute_flac_names --env flac_sample_rates \
		--env target_flacs --env target_folders --env target_sample_rates --env bits \
		--env sox_pre_input --env sox_pre_output --env target_bits_opt --env target_rate_cmd --env target_dither_cmd \
		--env flac_padding --env use_SOX_COMMAND_tag --env use_SOURCE_SPECS_tag --env use_SOURCE_FFP_tag --env embed_artwork --env sox_emits \
		--env metaflac_enabled --env sox_failures --env metaflac_failures --env imperfect_indexes --env verbose_output \
		--env red --env green --env bold --env orange --env default \
		${parallel_progress_bar[0]} ${paralleljobs[0]} --will-cite _execute ::: "${!target_flacs[@]}"

	parallel_exit_status="$?"
	if [[ $parallel_exit_status -gt "0" ]] ;then       # I *think* I've covered all the possibilities around parallel's exit status... overkill? or missing some key detail?
		if [[ $parallel_exit_status -eq "101" ]] ;then # if only we could get "success=X" exit-status functionality without using '--halt-on-error'! :/
			_message "${red}Done.${default} "
			_error "HUGE FAILURE: Over 100 targets failed at least 1 of their tasks!"
		elif [[ $parallel_exit_status -eq "255" ]] ;then
			_message "${orange}Done.${default} "
			_error "env_parallel reports '255' exit status, meaning 'other error', meaning... well, it's definitely NOT success!"
		elif [[ $parallel_exit_status -eq ${#target_flacs[@]} ]] ;then
			_message "${red}Done.${default} "
			_error "TOTAL FAILURE: EVERY TARGET failed at least 1 of their tasks!" # if #targets > 100 ;then user gets a different error than this, even if every target failed :/
		else
			_message "${orange}Done.${default} "
			_error "$parallel_exit_status (out of ${#target_flacs[@]}) target(s) failed at least 1 of their tasks!"
		fi
	else
	    _message -N "${green}Done${default}! Converted ${#target_flacs[@]} target(s) with no apparent failures."
	fi
fi
