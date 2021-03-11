#!/bin/bash

# AUTHOR: Michael Partridge <mcp292@nau.edu>
# https://git-scm.com/book/en/v2/Git-Internals-Maintenance-and-Data-Recovery

printf "\nCall with tee if you want to save output.\n"

printf "\nCAUTION: Removing a file will result in permanent removal of the "
printf "file from the repo and reflog.\n"

printf "\nFive largest files (can be less if file repeated and deleted). "
printf "Largest are prompted first.\n\n\n"

# TODO: man page with asciidoctor?
# TODO: optional param and tail is x4 of this (use enhanced get-opts)
MAX_PROCESSED=5
MAX_LIST=`expr $MAX_PROCESSED \* 4`

# Measure size (before)
git gc > /dev/null 2>&1

reposize_before=`git count-objects -v | grep size-pack: | cut -s -d " " -f 2`
total_reposize_before=$reposize_before
total_reposize_after=0
total_diff=0

# Locate largest and store in reverse (greatest to least)
readarray -t largest_list <<< `git verify-pack -v .git/objects/pack/*.idx | \
                               sort -nr -k 3 | head -n $MAX_LIST`

# Prompt user to remove 5 largest and report size difference
for ((ind=processed=0;
      processed < $MAX_PROCESSED && ind < ${#largest_list[@]};
      ind++))
do
    line=${largest_list[$ind]}
    
    hash=`printf "$line" | cut -d " " -f 1`
    file_size=`printf "$line" | tr -s " " | cut -s -d " " -f 3`

    fn=`git rev-list --objects --all | grep $hash | cut -s -d " " -f 2` 
    
    # if file found (may be deleted by previous iteration)
    if [ -n "$fn" ] && [ "$fn" != "" ] 
    then
        printf "Remove $fn ($file_size B)? [yes/no]: "
        read ans
        printf "\n"
        
        if [ "$ans" = "yes" ]
        then
            git filter-repo --invert-paths --path $fn

            # if call failed
            if [ $? -eq 1 ]
            then
                printf "\nDo you want to use --force? [yes/no]: "
                read ans
                printf "\n"
                
                if [ "$ans" = "yes" ]
                then
                    git filter-repo --force --invert-paths --path $fn
                else
                    exit 0
                fi
            fi
            
            # clean repo
            rm -Rf .git/refs/original
            rm -Rf .git/logs/
            git gc > /dev/null 2>&1

            # calc sizes
            reposize_after=`git count-objects -v | grep size-pack: | \
                            cut -s -d " " -f 2`
            diff=`expr $reposize_after - $reposize_before`
            
            # report repo size
            printf "\nbefore: $reposize_before KB\n"
            printf "after : $reposize_after KB\n"
            printf "diff  : $diff KB\n\n"

            # update sizes
            reposize_before=$reposize_after
            total_reposize_after=$reposize_after
            ((total_diff+=diff))
        fi

        ((processed++))
    fi
done

# TODO: report totals
# report total repo size
printf "\ntotal before: $total_reposize_before KB\n"
printf "total after : $total_reposize_after KB\n"
printf "total diff  : $total_diff KB\n\n"

