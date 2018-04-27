#!/bin/bash

_gitkeep()
{
    local current options
    COMPREPLY=()
    current="${COMP_WORDS[COMP_CWORD]}"
    options=("forward_merge clean setup")


    case "${COMP_WORDS[1]}" in
        forward_merge)
            if [ "${COMP_WORDS[COMP_CWORD-1]}" == "--base_branch" ] ; then
              local running=$(for x in `./gitkeep forward_merge --output_local`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${current}) )
            elif [ "${COMP_WORDS[COMP_CWORD-1]}" == "--merge_branch" ] ; then
              local running=$(for x in `./gitkeep forward_merge --output_remote`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${current}) )
            else
              local running=$(for x in `./gitkeep forward_merge -c`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${current}) )
            fi
            return 0
            ;;
        clean)
            if [ "${COMP_WORDS[COMP_CWORD-1]}" == "--base_branch" ] ; then
              local running=$(for x in `./gitkeep clean --output_local`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${current}) )
            elif [ "${COMP_WORDS[COMP_CWORD-1]}" == "--merge_branch" ] ; then
              local running=$(for x in `./gitkeep clean --output_remote`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${current}) )
            else
              local running=$(for x in `./gitkeep clean -c`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${current}) )
            fi
            return 0
            ;;
        setup)
           return 0
           ;;
        *)
        ;;
    esac


    COMPREPLY=( $(compgen -W "${options}" ${current}) )
    return 0
}
echo "loaded git script"
complete -F _gitkeep gitkeep
