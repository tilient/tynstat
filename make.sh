
### build 64 bit version ###
luajit -b -a x64 -n main src/tynstat.lua tynstat.o
gcc -m64 -Wl,-E tynstat.o lib/llj_64bit.a -lm -ldl -o bin/64bit/tynstat
rm tynstat.o

### build 32 bit version ###
luajit -b -a x86 -n main src/tynstat.lua tynstat.o
gcc -m32 -Wl,-E tynstat.o lib/llj_32bit.a -lm -ldl -o bin/32bit/tynstat
rm tynstat.o

