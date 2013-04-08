
### build 64 bit version ###
luajit -b -a x64 -n main tynstat.lua tynstat.o
gcc -m64 -Wl,-E tynstat.o llj_64bit.a -lm -ldl -o tynstat_64
rm tynstat.o

### build 32 bit version ###
luajit -b -a x86 -n main tynstat.lua tynstat.o
gcc -m32 -Wl,-E tynstat.o llj_32bit.a -lm -ldl -o tynstat_32
rm tynstat.o

