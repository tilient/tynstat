luajit -b -n main tynstat.lua tynstat.o
gcc -Wl,-E tynstat.o llj.a -lm -ldl -o tynstat
rm tynstat.o

