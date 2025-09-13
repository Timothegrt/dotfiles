# This is a sample commands.py.  You can add your own commands here.
#
# Please refer to commands_full.py for all the default commands and a complete
# documentation.  Do NOT add them all here, or you may end up with defunct
# commands when upgrading ranger.

# A simple command for demonstration purposes follows.
# -----------------------------------------------------------------------------

from __future__ import (absolute_import, division, print_function)

# You can import any python module as needed.
import os

# You always need to import ranger.api.commands here to get the Command class:
from ranger.api.commands import Command


# Any class that is a subclass of "Command" will be integrated into ranger as a
# command.  Try typing ":my_edit<ENTER>" in ranger!
class my_edit(Command):
    # The so-called doc-string of the class will be visible in the built-in
    # help that is accessible by typing "?c" inside ranger.
    """:my_edit <filename>

    A sample command for demonstration purposes that opens a file in an editor.
    """

    # The execute method is called when you run this command in ranger.
    def execute(self):
        # self.arg(1) is the first (space-separated) argument to the function.
        # This way you can write ":my_edit somefilename<ENTER>".
        if self.arg(1):
            # self.rest(1) contains self.arg(1) and everything that follows
            target_filename = self.rest(1)
        else:
            # self.fm is a ranger.core.filemanager.FileManager object and gives
            # you access to internals of ranger.
            # self.fm.thisfile is a ranger.container.file.File object and is a
            # reference to the currently selected file.
            target_filename = self.fm.thisfile.path

        # This is a generic function to print text in ranger.
        self.fm.notify("Let's edit the file " + target_filename + "!")

        # Using bad=True in fm.notify allows you to print error messages:
        if not os.path.exists(target_filename):
            self.fm.notify("The given file does not exist!", bad=True)
            return

        # This executes a function from ranger.core.acitons, a module with a
        # variety of subroutines that can help you construct commands.
        # Check out the source, or run "pydoc ranger.core.actions" for a list.
        self.fm.edit_file(target_filename)

    # The tab method is called when you press tab, and should return a list of
    # suggestions that the user will tab through.
    # tabnum is 1 for <TAB> and -1 for <S-TAB> by default
    def tab(self, tabnum):
        # This is a generic tab-completion function that iterates through the
        # content of the current directory.
        return self._tab_directory_content()


class trash(Command):
    """:trash
    Move selection to trash using trash-cli."""
    def execute(self):
        import subprocess
        files = [f.realpath for f in self.fm.thistab.get_selection()]
        if files:
            self.fm.notify("Trashing: " + ", ".join([f.split("/")[-1] for f in files]))
            subprocess.call(["trash-put"] + files)

class mkcd(Command):
    """:mkcd <dirname>  – create dir and cd into it"""
    def execute(self):
        import os
        from os.path import join, expanduser
        dirname = join(self.fm.thisdir.path, expanduser(self.rest(1)))
        os.makedirs(dirname, exist_ok=True)
        self.fm.cd(dirname)


class fzf_select(Command):
    """:fzf_select – Jump to file/dir with fzf."""
    def execute(self):
        import subprocess, os
        fzf = self.fm.execute_command(
            "fzf --ansi --preview 'bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || ls -la --color=always {}'".format("{+}", "{+}"),
            universal_newlines=True, stdout=subprocess.PIPE)
        selection = fzf.stdout.strip().split("\n")
        if selection:
            path = selection[0]
            if os.path.isdir(path):
                self.fm.cd(path)
            else:
                self.fm.select_file(path)

from ranger.api.commands import Command
import subprocess, json

class udisks_mount(Command):
    """:udisks_mount
    Interaktiv Partition wählen und mit udisksctl mounten."""
    def execute(self):
        lsblk = subprocess.check_output(
            ["lsblk", "-J", "-o", "PATH,NAME,LABEL,FSTYPE,SIZE,TYPE,MOUNTPOINT,RM"]
        ).decode()
        data = json.loads(lsblk)["blockdevices"]
        # flache Liste aller Partitionen
        parts = []
        def walk(devs):
            for d in devs:
                if d.get("type") == "part":
                    parts.append(d)
                if d.get("children"):
                    walk(d["children"])
        walk(data)
        if not parts:
            self.fm.notify("Keine Partitionen gefunden.", bad=True); return
        # fzf-Auswahl
        lines = []
        for p in parts:
            lbl = p.get("label") or "-"
            mp  = p.get("mountpoint") or "-"
            lines.append(f'{p["path"]}\t{lbl}\t{p.get("fstype") or "-"}\t{p.get("size")}\t{mp}')
        fzf = self.fm.execute_command(
            "fzf --ansi --with-nth=1,2,3,4 --prompt='mount> '",
            universal_newlines=True, stdout=subprocess.PIPE, stdin=subprocess.PIPE
        )
        out = fzf.communicate(input="\n".join(lines))[0].strip()
        if not out: return
        dev = out.split("\t", 1)[0]
        # schon gemountet?
        if any(dev in l and "\t-" not in l for l in lines if l.startswith(dev)):
            self.fm.notify(f"{dev} scheint bereits gemountet.", bad=True); return
        rc = subprocess.call(["udisksctl", "mount", "-b", dev])
        self.fm.notify("OK" if rc == 0 else "Fehler", bad=(rc!=0))

class udisks_unmount(Command):
    """:udisks_unmount
    Gemountete Partition wählen und unmounten."""
    def execute(self):
        mounts = subprocess.check_output(["lsblk", "-J", "-o", "PATH,MOUNTPOINT,TYPE"]).decode()
        data = json.loads(mounts)["blockdevices"]
        items = []
        def walk(devs):
            for d in devs:
                if d.get("type") == "part" and d.get("mountpoint"):
                    items.append(f'{d["path"]}\t{d["mountpoint"]}')
                if d.get("children"):
                    walk(d["children"])
        walk(data)
        if not items:
            self.fm.notify("Keine gemounteten Partitionen.", bad=True); return
        fzf = self.fm.execute_command(
            "fzf --ansi --with-nth=1,2 --prompt='umount> '",
            universal_newlines=True, stdout=subprocess.PIPE, stdin=subprocess.PIPE
        )
        out = fzf.communicate(input="\n".join(items))[0].strip()
        if not out: return
        dev = out.split("\t", 1)[0]
        rc = subprocess.call(["udisksctl", "unmount", "-b", dev])
        self.fm.notify("OK" if rc == 0 else "Fehler", bad=(rc!=0))

