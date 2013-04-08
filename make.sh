
### build 64 bit versions ###
luajit -b -a x64 src/tynstat.lua tynstat.o
luajit -b -a x64 -n main -e "require('tynstat'); main();"    main.o
luajit -b -a x64 -n main -e "require('tynstat'); daemain();" daemain.o
gcc -m64 -Wl,-E main.o    tynstat.o lib/llj_64bit.a -lm -ldl -o bin/64bit/tynstat
gcc -m64 -Wl,-E daemain.o tynstat.o lib/llj_64bit.a -lm -ldl -o bin/64bit/tynstad
rm tynstat.o main.o daemain.o

### build 32 bit versions ###
luajit -b -a x86 src/tynstat.lua tynstat.o
luajit -b -a x86 -n main -e "require('tynstat'); main();"    main.o
luajit -b -a x86 -n main -e "require('tynstat'); daemain();" daemain.o
gcc -m32 -Wl,-E main.o    tynstat.o lib/llj_32bit.a -lm -ldl -o bin/32bit/tynstat
gcc -m32 -Wl,-E daemain.o tynstat.o lib/llj_32bit.a -lm -ldl -o bin/32bit/tynstad
rm tynstat.o main.o daemain.o

