Useage
------

Run *tynstat_32* or *tynstat_64* on a server.

*tynstad_32* and *tynstad_64* are the daemonized versions.

To get stats info about the server in HTML format, point your browser 
to: `http://servername:27272/html`
To get the stat info about the server as a JSON file, point 
at: `http://servername:27272/json`

Note
----

This is only tested on a 64-bit and 32-bit Ubuntu 12.04.


Building it
-----------

You need *gcc* (`sudo apt-get install build-essential`) and 
[*luajit*](http://luajit.org/) to build *tynstat*.

`sh make.sh` creates both the 32-bit and 64-bit versions. Make
sure your build environment can deal with that. E.g. for Ubuntu
make sure you installed the multilib version of g++.
(`sudo apt-get install g++-multilib`).

If all of this is installed, run `sh make.sh` to build *tynstat_32* 
and *tynstat_64*.

If you don't care about the different bit-versions, 
just ignore the errors or comment out the lines you don't want.


Files
-----

- tynstat.lua : source code
- make.sh     : script to build executables
- readme.md   : this file

- llj_32bit.a : patched version of 32-bit version luajit library
- llj_64bit.a : patched version of 64-bit version luajit library

- tynstat_32  : executable, 32 bit
- tynstat_64  : executable, 64 bit
- tynstad_32  : executable, 32 bit, daemonized
- tynstad_64  : executable, 64 bit, daemonized

Contact
-------

wiffel@tilient.org

