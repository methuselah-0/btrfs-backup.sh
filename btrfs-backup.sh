# run once only.
function snapshot_harddrive_new(){
    #local backup_source="~/hd/Hårddisk"
    local backup_source="/"
    local backup_dir="/backups"
    local backup_dest="/mnt/backups/"
    local date="$(date +%Y-%m-%d_%H:%M)"
    echo "${backup_source}"
    echo "${backup_dir}"
    echo "${backup_dest}"
    echo "${date}"
    read -p "Would you like to proceed?"
    case "${REPLY}" in
	y|Y) sudo mkdir -p "${backup_dest}" && sudo mkdir -p "${backup_dir}"
	     sudo btrfs subvolume snapshot -r "${backup_source}" "${backup_dir}/snapshot_${date}"
	     sudo btrfs send "/backups/snapshot_${date}" | sudo btrfs receive "${backup_dest}"
	     ;;
	*) return 0
	   ;;
    esac
}
# run this to backup to external harddrive at "backup_dest" specified below.
function snapshot_harddrive(){
    shopt -s extglob
    local backup_source="/"
    local backup_dir="/backups"    
    local backup_dest="/mnt/backups"
    local date="$(date +%Y-%m-%d_%H:%M)"
    local keep_number=1 # old snapshots to keep in $backup_dir
    
    mkdir -p "${backup_dest}" && mkdir -p "${backup_dir}"    

    # the most recent snapshot from backup source dir at index 0
    mapfile parent_sources -t < <( find ${backup_dir} -maxdepth 1 -name '*snapshot_*' -printf '%T %p\n' | sort -r | awk ' { print $2 } ' )

    # find most recent backup on backup target filesystem, and use the corresponding backup from source backup folder as the parent
    local parent_on_dest="$(find ${backup_dest} -maxdepth 1 -name '*snapshot_*' -printf '%T %p\n' | sort -r | head -n 1 | awk ' { print $2 } ')"
    local parent_vol="${parent_on_dest##*/}"
    local parent="${backup_dir}/${parent_vol}"
    if [[ -z "$parent" ]]
    then
	printf '%s\n' "No parent exist. Use the command snapshot_harddrive_new first."
	return 1
    fi

    # List to delete vols from index keep_number and forward, assuming
    # parent_sources is listed with the most recent backup at index 0.
    local del_vols=( ${parent_sources[@]:$keep_number:${#parent_sources[@]}} )
    for vol in "${del_vols[@]}"
    do
	echo "Will delete: $vol"
    done
    for vol in ${parent_sources[@]:0:$keep_number}
    do
	echo "Will keep $vol"
    done
    echo "backup_source: ${backup_source}"
    echo "backup_dest: ${backup_dest}"
    echo "date: ${date}"
    echo "parent: ${parent}"    
    read -p "Would you like to proceed? [y/n]"
    case "${REPLY}" in
	y|Y) sudo btrfs subvolume snapshot -r "${backup_source}" "${backup_dir}/snapshot_${date}"
	     printf '%s\n' "Read-only snapshot created at: ${backup_dir}/snapshot_${date}"
	     sync
	     printf '%s\n' "Starting incremental backup.."
	     sudo btrfs send -p "${parent}" "${backup_dir}/snapshot_${date}" | sudo btrfs receive "${backup_dest}/"
	     printf '%s\n' "Incremental backup finished."
	     ;;
	*) return 0
	   ;;
    esac
    printf '%s\n' "Now deleting ${#del_vols[@]} old subvolumes"
    for vol in "${del_vols[@]}"
    do
	sudo btrfs subvolume delete "$vol"
    done
}
# run as root, e.g. as a cronjob
function snapshot_harddrive_local(){
    shopt -s extglob
    local backup_source="/"
    local backup_dir="/backups_local"    
    local date="$(date +%Y-%m-%d_%H:%M)"

    # old snapshots to keep in $backup_dir. With daily backups this means 30 days back. 
    local keep_number=30 
    
    mkdir -p "${backup_dir}"    

    # the most recent snapshot from backup source dir at index 0
    mapfile parent_sources -t < <( find ${backup_dir} -maxdepth 1 -name '*snapshot_*' -printf '%T %p\n' | sort -r | awk ' { print $2 } ' )

    # find most recent backup on backup target filesystem, and use the corresponding backup from source backup folder as the parent

    # List to delete vols from index keep_number and forward, assuming
    # parent_sources is listed with the most recent backup at index 0.
    local del_vols=( ${parent_sources[@]:$keep_number:${#parent_sources[@]}} )
    for vol in "${del_vols[@]}"
    do
	echo "Will delete: $vol"
    done
    for vol in ${parent_sources[@]:0:$keep_number}
    do
	echo "Will keep $vol"
    done
    echo "backup_source: ${backup_source}"
    echo "backup_dir: ${backup_dir}"
    echo "date: ${date}"
    if [[ "$1" != "-y" ]]
    then
        read -p "Would you like to proceed? [y/n]"
        case "${REPLY}" in
            y|Y) btrfs subvolume snapshot -r "${backup_source}" "${backup_dir}/snapshot_${date}"
	         printf '%s\n' "Read-only snapshot created at: ${backup_dir}/snapshot_${date}"
	         sync
	         ;;
	    *) return 0
	       ;;
        esac
    else
        btrfs subvolume snapshot -r "${backup_source}" "${backup_dir}/snapshot_${date}"
        printf '%s\n' "Read-only snapshot created at: ${backup_dir}/snapshot_${date}"
        sync
    fi
    printf '%s\n' "Now deleting ${#del_vols[@]} old subvolumes"
    for vol in "${del_vols[@]}"
    do
	btrfs subvolume delete "$vol"
    done
}
