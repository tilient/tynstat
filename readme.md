Usage
-----

Run *tynstat* or *tynstad* (daemonized version) on a server.

To get stats info about the server in HTML format, point your browser 
to: `http://servername:27272/html`
To get the stat info about the server as a JSON file, point 
at: `http://servername:27272/json`


Note
----

This is only tested on Ubuntu 12.04.


Building it
-----------

You need *gcc* (`sudo apt-get install build-essential`) and 
[*luajit*](http://luajit.org/) to build *tynstat*.

`sh make.sh` creates both the 32-bit and 64-bit versions and
both the daemonized and normal versions. Make
sure your build environment can deal with that. E.g. for Ubuntu
make sure you installed the multilib version of g++.
(`sudo apt-get install g++-multilib`).

If all this is properly installed, run `sh make.sh` to build 
all executables.

If you don't care about the different bit-versions, 
just ignore the errors or comment out the lines you don't want.


Files
-----

- readme.md          : this file
- make.sh            : script to build executables
- src/tynstat.lua    : source code
- lib/llj_32bit.a    : patched version of 32-bit luajit library
- lib/llj_64bit.a    : patched version of 64-bit luajit library
- bin/64bit/tynstat  : executable, 64 bit
- bin/64bit/tynstad  : executable, 64 bit, daemonized
- bin/32bit/tynstat  : executable, 32 bit
- bin/32bit/tynstad  : executable, 32 bit, daemonized

Contact
-------

wiffel@tilient.org

