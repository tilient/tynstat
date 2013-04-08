
### build 64 bit version ###
luajit -b -a x64 tynstat.lua tynstat.o
luajit -b -a x64 -n main -e "require('tynstat'); main();"    main.o
luajit -b -a x64 -n main -e "require('tynstat'); daemain();" daemain.o
gcc -m64 -Wl,-E main.o    tynstat.o llj_64bit.a -lm -ldl -o tynstat_64
gcc -m64 -Wl,-E daemain.o tynstat.o llj_64bit.a -lm -ldl -o tynstad_64
rm tynstat.o main.o daemain.o

### build 32 bit version ###
luajit -b -a x86 tynstat.lua tynstat.o
luajit -b -a x86 -n main -e "require('tynstat'); main();"    main.o
luajit -b -a x86 -n main -e "require('tynstat'); daemain();" daemain.o
gcc -m32 -Wl,-E main.o    tynstat.o llj_32bit.a -lm -ldl -o tynstat_32
gcc -m32 -Wl,-E daemain.o tynstat.o llj_32bit.a -lm -ldl -o tynstad_32
rm tynstat.o main.o daemain.o

