#!/usr/bin/env python3
"""Briefly show a Unicode character count on the copying pane's bottom border."""
import subprocess
import sys
import time
import uuid


def tmux(*args):
    return subprocess.check_output(["tmux", *args])


def main():
    client, pane = sys.argv[1:3]
    text = tmux("save-buffer", "-").decode("utf-8", "replace")
    token = uuid.uuid4().hex
    tmux("set-option", "-p", "-t", pane, "@copy_notice", f"{len(text)} characters copied",
         ";", "set-option", "-p", "-t", pane, "@copy_notice_token", token,
         ";", "refresh-client", "-t", client)
    time.sleep(1.5)
    # An older timer must not clear a newer copy notification.
    tmux("if-shell", "-F", "-t", pane,
         "#{==:#{@copy_notice_token}," + token + "}",
         "set-option -pu -t " + pane + " @copy_notice ; "
         "set-option -pu -t " + pane + " @copy_notice_token ; "
         "refresh-client -t " + client)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError:
        # The pane or client may have closed during the notification delay.
        pass
