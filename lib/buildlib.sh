#
# first path luajit.c
# then make
# them ...
cp LuaJIT-2.0.1/src/luajit.o .
cp LuaJIT-2.0.1/src/libluajit.a .
cp libluajit.a llj.a
ar -r llj.a luajit.o

