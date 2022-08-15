g++-12 -Wl,-rpath=$HOME/opt/gcc-12/x86_64/lib64 -L$HOME/opt/gcc-12/x86_64/lib64 $(pkg-config --cflags --libs --static lua53) -fPIC -o libncmcpp.so -shared -std=c++20 ncm.cpp

#g++-12 -fPIC -o libncmcpp.so -shared -std=c++20 ncm.cpp $(pkg-config --cflags --libs lua53)
