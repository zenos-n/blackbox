import gettext
import subprocess
from urllib.parse import unquote
from gi.repository import GObject, Nautilus

_ = gettext.translation("blackbox", fallback=True).gettext


class OpenBlackBoxExtension(GObject.GObject, Nautilus.MenuProvider):
    def _open_terminal(self, folder: Nautilus.FileInfo) -> None:
        path = unquote(folder.get_uri()[len("file://"):])
        subprocess.Popen(["blackbox-terminal", "--working-directory", path])

    def get_file_items(self, files: list) -> list:
        if len(files) != 1:
            return []

        file = files[0]
        if not file.is_directory() or file.get_uri_scheme() != "file":
            return []

        item = Nautilus.MenuItem(
            name="OpenBlackBox::open_file",
            label=_("Open in Black Box"),
            tip=_("Open Black Box in \"%s\"") % file.get_name(),
        )
        item.connect("activate", lambda _, f: self._open_terminal(f), file)
        return [item]

    def get_background_items(self, current_folder: Nautilus.FileInfo) -> list:
        item = Nautilus.MenuItem(
            name="OpenBlackBox::open_background",
            label=_("Open in Black Box"),
            tip=_("Open Black Box in \"%s\"") % current_folder.get_name(),
        )
        item.connect("activate", lambda _, f: self._open_terminal(f), current_folder)
        return [item]
