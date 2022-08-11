g++-12 -fPIC -o libncmcpp.so -shared -std=c++20 ncm.cpp $(pkg-config --cflags --libs lua53)
