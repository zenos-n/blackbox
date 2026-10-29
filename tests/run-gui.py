#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run GTK tests without reading or changing the user's settings and themes."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix="blackbox-tests-") as directory:
    env = os.environ.copy()
    env.update(HOME=directory, XDG_DATA_HOME=f"{directory}/data",
               XDG_CONFIG_HOME=f"{directory}/config",
               XDG_CACHE_HOME=f"{directory}/cache")
    shutil.copytree(Path(env["BLACKBOX_TEST_SOURCE"]) / "data/schemes",
                    Path(env["XDG_DATA_HOME"]) / "blackbox-next/schemes")
    sys.exit(subprocess.run(sys.argv[1:], env=env).returncode)
