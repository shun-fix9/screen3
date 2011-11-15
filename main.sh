# screen3
screen3_sessions(){
	sessions=(S:home)
}

screen3_entries(){
	: # entries= list of "path title\n"
}

screen3_work_dir(){
	work_dir=~/.screen3
}
screen3_screen_command(){
	: # screen_command=path/to/screen(full-path)
}
screen3_session_prefix(){
	: # session_prefix="session name"
}

screen3_setting_S(){
	escape_char="^@"
	: # escape_char2= $escape_char
	hint_char=" "
	: # bg_color= color expression
	hi_color="b Bw"
}
screen3_setting_M(){
	escape_char="^q"
	: # escape_char2= $escape_char
	hint_char="q"
	bg_color=" Yk"
	hi_color="b Rw"
}
screen3_setting_D(){
	escape_char="^a"
	: # escape_char2= $escape_char
	hint_char="a"
	bg_color=" gk"
	hi_color="b Yk"
}

screen3_create_class_name(){
	: # menu_class_name=menu
	: # create_class_name=create
}
screen3_create_command(){
	: # create_command=C
}
screen3_reload_command(){
	: # reload_command=@
}

screen3_setting_hardstatus(){
	hardstatus="$bg_color $hostname %0$pre_sep_pos= | %0$post_sep_pos=%-w$hi_color%50>%n %t%{-}%+w %=%80<%=[%l]($hint_char)"
}


screen3(){
	screen3_load_file ~/.screen3rc
	screen3_load_file ~/.screen3rc.d/`hostname`

	local work_dir
	local init_error; screen3_init
	[ "$init_error" ] && return

	local screen_command; screen3_set_screen_command
	[ -z "$screen_command" ] && return

	local screen_session
	local screen_mode
	local screen_name
	local screen_session_name
	local screen_session_exists

	screen3_select_session
	while [ "$screen_session" ]; do
		screen3_attach
		screen3_select_session
	done

	screen3_restore_window_title
}

screen3_init(){
	screen3_work_dir
	if [ ! -d "$work_dir" ]; then
		mkdir -p "$work_dir"
	fi
	if [ ! -d "$work_dir" ]; then
		echo "cannot create work dir: $work_dir"
		init_error=1
	fi
}

screen3_set_screen_command(){
	screen3_screen_command
	if [ -z "$screen_command" ]; then
		screen_command=screen

		local screen_alias
		screen_alias=`alias | grep "^alias $screen_command=.*" | sed "s/^alias $screen_command='\\(.*\\)'$/\1/"`
		if [ "$screen_alias" ]; then
			screen_command=$screen_alias
		fi
	fi
}

screen3_select_session(){
	local continue_select; continue_select=1
	local input_continue
	while [ "$continue_select" ]; do
		screen3_select_session_number

		if [ -z "$screen_session" ]; then
			return
		fi

		echo
		echo "session found: '$screen_session' mode: $screen_mode"
		echo
		echo -n "use this session? [no] "
		read input_continue

		case "$input_continue" in
			n*|N*)
				continue_select=1
				;;
			*)
				continue_select=
				;;
		esac
	done
}
screen3_select_session_number(){
	screen_session=
	screen_mode=
	screen_name=
	screen_session_name=
	screen_session_exists=

	local session_prefix; screen3_session_prefix
	[ -z "$session_prefix" ] && session_prefix=screen3

	local -a sessions; screen3_sessions
	screen3_init_sessions
	local default_session_number

	if [ ${#sessions[*]} -gt 1 ]; then
		default_session_number=1
	else
		default_session_number=0
	fi

	echo
	echo "enable sessions..."
	screen3_sessions_for screen3_echo_session

	local input_session_number
	local detect_session
	local is_exit
	screen3_input_session_number
	[ "$is_exit" ] && return
	while [ -z "$detect_session" ]; do
		screen3_input_session_number
		[ "$is_exit" ] && return
	done

	screen_session=${sessions[$input_session_number]}

	case "$screen_session" in
		S:*)
			screen_mode=S
			screen_name=${screen_session#S:}
			;;
		M:*)
			screen_mode=M
			screen_name=${screen_session#M:}
			;;
		D:*)
			screen_mode=D
			screen_name=${screen_session#D:}
			;;
		*)
			echo "cannot detect session mode($screen_session): run 'S' mode"
			screen_mode=S
			screen_name=$screen_session
			;;
	esac

	screen_session_name="$session_prefix:$screen_session"
	screen_session_exists=`$screen_command -list | grep "^[[:space:]]*[[:digit:]]*\.$screen_session_name.*(\\(De\|At\\)tached)$"`
}
screen3_init_sessions(){
	local tmp_sessions; tmp_sessions=${sessions[*]}
	sessions=(S:home)

	local session
	for session in ${tmp_sessions[*]}; do
		sessions[${#sessions[*]}]=$session
	done
}
screen3_sessions_for(){
	local func; func=$1; shift
	local session
	local -i session_number; session_number=0
	for session in ${sessions[*]}; do
		$func
		session_number=$session_number+1
	done
}
screen3_detect_session(){
	if [ "$session_number" = "$input_session_number" ]; then
		detect_session=$session
	fi
}
screen3_echo_session(){
	echo -n $session_number : $session

	if [ "$session_number" = "$default_session_number" ]; then
		echo -n " (default)"
	fi

	local exist_session;
	exist_session=`$screen_command -list | grep "^[[:space:]]*[[:digit:]]*\.$session_prefix:$session.*(\\(De\|At\\)tached)$"`
	if [ "$exist_session" ]; then
		echo -n " exists: $exist_session"
	fi

	echo
}
screen3_input_session_number(){
	echo
	echo -n "select session(or [exit|quit]): "
	read input_session_number
	if [ -z "$input_session_number" ]; then
		input_session_number=$default_session_number
	fi
	case "$input_session_number" in
		exit|quit)
			is_exit=1
			;;
	esac

	detect_session=
	screen3_sessions_for screen3_detect_session
}

screen3_attach(){
	local rc; rc=$work_dir/rc
	local hostname; screen3_set_hostname

	screen3_change_window_title

	screen3_generate_rc
	screen3_exec_screen
}

screen3_exec_screen(){
	if [ -z "$screen_session_exists" ]; then
		$screen_command -S "$screen_session_name" -c "$rc"
	else
		$screen_command -x -r "$screen_session_name"
	fi
}


screen3_generate_rc(){
	screen3_truncate_rc
	screen3_append_load_default_rc

	screen3_append_escape_and_hardstatus

	screen3_append_create_entries
}
screen3_truncate_rc(){
	cat /dev/null > "$rc"
}
screen3_append_load_default_rc(){
	local rc_file; rc_file=~/.screenrc
	[ -f "$rc_file" ] && echo "source $rc_file" >> "$rc"
}

screen3_append_escape_and_hardstatus(){
	local escape_char
	local escape_char2
	local hardstatus
	local hint_char
	local bg_color
	local hi_bg_color
	local hi_color
	screen3_setting_$screen_mode

	local pre_sep_pos
	local post_sep_pos
	screen3_set_separator_position

	screen3_fill_escape_and_color

	screen3_setting_hardstatus

	echo "escape $escape_char$escape_char2" >> "$rc"
	echo "hardstatus alwayslastline \"$hardstatus\"" >> "$rc"
}
screen3_set_separator_position(){
	local -i hostname_length
	hostname_length=${#hostname}

	# left padding 1
	hostname_length=$hostname_length+1
	pre_sep_pos=$hostname_length

	# left padding 1
	# right padding 1
	# separator "|".length = 1
	# => 3
	hostname_length=$hostname_length+3
	post_sep_pos=$hostname_length
}
screen3_fill_escape_and_color(){
	if [ -z "$escape_char" ]; then
		escape_char="^@"
	fi
	if [ -z "$escape_char2" ]; then
		escape_char2=$escape_char
	fi
	if [ -z "$hint_char" ]; then
		hint_char=$escape_char
	fi

	if [ -z "$bg_color" ]; then
		bg_color=""
	else
		bg_color="%{=$bg_color}"
	fi
	if [ -z "$hi_color" ]; then
		hi_color=""
	else
		hi_color="%{=$hi_color}"
	fi
}

screen3_append_create_entries(){
	local create_command
	local reload_command
	local menu_class_name
	local create_class_name
	screen3_set_command_names

	local entries; screen3_entries
	screen3_set_default_entry
	local autoload; screen3_set_autoload

	local awk_function; screen3_set_awk_function

	echo "bind @ source $rc" >> "$rc"

	echo "$entries" | awk \
		-v screen_mode="$screen_mode" \
		-v create_command="$create_command" \
		-v menu_class_name="$menu_class_name" \
		-v create_class_name="$create_class_name" \
		-v autoload="$autoload" \
		"$awk_function" >> "$rc"
}
screen3_set_command_names(){
	screen3_create_class_name
	[ -z "$create_class_name" ] && create_class_name="create"
	[ -z "$menu_class_name" ] && menu_class_name="menu"

	screen3_create_command
	[ -z "$create_command" ] && create_command=C

	screen3_reload_command
	[ -z "$reload_command" ] && reload_command=@
}
screen3_set_default_entry(){
	case "$screen_mode" in
		M|D)
			entries="localhost : local
$entries"
			;;
	esac
}
screen3_set_autoload(){
	autoload=0
	if [ -z "$screen_session_exists" ]; then
		if [ ! -z "$entries" ]; then
			autoload=1
		fi
	fi
}
screen3_set_awk_function(){
	awk_function=`cat <<\_____AWK
BEGIN {
	FS="[ \t]*:[ \t]*"
	count=0
	page=0
	menu=""
	global_menu=""
}
NF > 0 {
	if(count >= 10){
		printMenu(0)
		menu=""
		page++
		count=0
	}

	entry=getEntry()
	if(autoload > 0){
		print entry
		autoload=0
	}

	if(page == 0 && count == 0){
		print "bind c " entry
		print "bind ^c " entry
	}

	print "bind -c " create_class_name page " " count " " entry
	menu=menu "[ " count " " $2 " ]"

	count++
}
END {
	if(count > 0){
		printMenu(1)
		if(page > 0){
			printGlobalMenu()
		}
	}
}
function getEntry(){
	if(NF == 1){
		title=$1
	} else {
		title=$2
	}

	if(title != "local" && screen_mode != "S"){
		return "eval 'screen -t " title " ssh " $3 " " $1 "' 'msgwait 1' 'echo " title "'"
	} else {
		return "eval 'chdir " $1 "' 'screen -t " title "' 'chdir' 'msgwait 1' 'echo " title "'"
	}
}
function printMenu(isEnd){
	menu_command=getMenu(menu, create_class_name page)

	if(isEnd == 0 || page > 0){
		global_menu=global_menu "[ " page " ]"
		print "bind -c " menu_class_name " " page " " menu_command

		if(isEnd > 0){
			printCancel(menu_class_name)
		}
	} else {
		print "bind " create_command " " menu_command
	}

	printCancel(create_class_name page)
}
function printGlobalMenu(){
	print "bind " create_command " " getMenu(global_menu, menu_class_name)
}
function getMenu(menu_string, class_name){
	return "eval 'command -c " class_name "' 'msgwait 20' 'echo \"" menu_string "( - cancel )\"'"
}
function printCancel(class_name){
	print "bind -c " class_name " - msgwait 1"
}
_____AWK`
}

screen3_set_hostname(){
	screen3_hostname
	hostname="$screen_session.$hostname"
}
screen3_hostname(){
	if [ -z "$HOST" ]; then
		if [ -z "$HOSTNAME" ]; then
			hostname=`hostname`
		else
			hostname=$HOSTNAME
		fi
	else
		hostname=$HOST
	fi
	# strip
	hostname=`echo $hostname | sed 's/\(\.[^.]*\)*$//'`
}
screen3_user(){
	if [ -z "$USER" ]; then
		user=`whoami`
	else
		user=$USER
	fi
}

screen3_change_window_title(){
	if [ $TERM != "screen" ]; then
		local user; screen3_user
		echo -ne "\e]0;${user}@${hostname}\007"
	else
		echo -ne "\ek${hostname}\e\\"
	fi
}
screen3_restore_window_title(){
	if [ $TERM != "screen" ]; then
		echo -ne "\e]0;${USER}@${HOSTNAME}\007"
	fi
}

screen3_load_file(){
	[ -f "$1" ] && . $1
}

screen3
