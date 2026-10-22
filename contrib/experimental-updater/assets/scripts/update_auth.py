#!/usr/bin/python3
"""Adapt paru's sudo invocations to the desktop polkit agent."""
import os
import sys


def command_for(args):
    args = list(args)
    while args and args[0].startswith('-'):
        flag = args.pop(0)
        if flag == '--':
            break
        if flag in ('-v', '--validate', '-k', '--reset-timestamp', '-n', '--non-interactive'):
            continue
        if flag in ('-u', '--user') and args and args.pop(0) == 'root':
            continue
        raise ValueError(f'Argumento de autorización no compatible: {flag}')
    # Validation does not run anything; each actual privileged command uses polkit.
    if not args:
        return None
    return ['/usr/bin/pkexec', '--disable-internal-agent', *args]


if __name__ == '__main__':
    try:
        command = command_for(sys.argv[1:])
    except ValueError as error:
        sys.exit(str(error))
    if command:
        os.execv(command[0], command)
