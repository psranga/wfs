#include <iostream>
#include <fstream>
#include <filesystem>
#include <cstdint>

#if 0
#define FMT_HEADER_ONLY
#include "fmt/core.h"
#endif

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

static void print_space_info(auto const& dirs, int width = 14)
{
    std::cout << std::left;
    for (const auto s : {"Capacity", "Free", "Available", "Dir"})
        std::cout << "│ " << std::setw(width) << s << ' ';
    std::cout << '\n';
    std::error_code ec;
    for (auto const& dir : dirs) {
        const std::filesystem::space_info si = std::filesystem::space(dir, ec);
        std::cout
            << "│ " << std::setw(width) << static_cast<std::intmax_t>(si.capacity) << ' '
            << "│ " << std::setw(width) << static_cast<std::intmax_t>(si.free) << ' '
            << "│ " << std::setw(width) << static_cast<std::intmax_t>(si.available) << ' '
            << "│ " << dir << '\n';
    }
}
 
static int ncm_add1(lua_State* L) {
  int n = (int)lua_tonumber(L, 1);
  n = n + 1;
  lua_pushnumber(L, n);
  return 1;
}

static std::string int_to_hex64(std::uint64_t n) {
#if 1
  std::ostringstream os;
  os << "0x" << std::setbase(16) << std::setw(16) << std::setfill('0') << n << std::flush;
  return std::move(os.str());
#else
  const char* digits = "0123456789abcdef";
  std::string s("0x0123456789abcdef");

  for (int i = 0; i < 16; ++i) {
    std::uint64_t q = n / 16;
    std::uint64_t r = n % 16;
    s.at(15+2-i) = digits[r];
    n = q;
  }

  return std::move(s);
#endif
}

// -------------------------------------------

static int ncm_fs_space(lua_State* L) {
  const char *dn = lua_tostring(L, 1);
  if (dn == 0) return 0;

  std::error_code ec;
  const std::filesystem::space_info si = std::filesystem::space(dn, ec);
  if (ec.value() != 0) return 0;

  lua_newtable(L);
  lua_pushstring(L, "capacity");
  lua_pushinteger(L, static_cast<lua_Integer>(si.capacity));
  lua_settable(L, -3);
  lua_pushstring(L, "free");
  lua_pushinteger(L, static_cast<lua_Integer>(si.free));
  lua_settable(L, -3);
  lua_pushstring(L, "available");
  lua_pushinteger(L, static_cast<lua_Integer>(si.available));
  lua_settable(L, -3);

  return 1;
}

static int ncm_fs_hash_value(lua_State* L) {
  using std::filesystem::hash_value;
  using std::filesystem::path;

  const char *pn = lua_tostring(L, 1);  // any path.
  if (pn == 0) return 0;

  const std::size_t h = hash_value(path(pn));

  lua_pushstring(L, int_to_hex64(h).c_str());

  return 1;
}

static int ncm_int_to_hex64(lua_State* L) {
  lua_Integer n = lua_tointeger(L, 1);
#if 0
#if 0
  const char* digits = "0123456789abcdef";
  std::string s("0123456789abcdef");

  for (int i = 0; i < 16; ++i) {
    lua_Integer q = n / 16;
    lua_Integer r = n % 16;
    s[15-i] = digits[r];
    n = q;
  }

  lua_pushstring(L, s.c_str());
#endif

  std::ostringstream os;
  os << "0x" << std::setbase(16) << std::setw(16) << std::setfill('0') << n << std::flush;
  lua_pushstring(L, os.str().c_str());
#endif

  lua_pushstring(L, int_to_hex64(n).c_str());
  return 1;
}

static int ncm_create_file(lua_State* L) {
  char buf[4096];

  const char* block_fn = lua_tostring(L, 1);
  std::size_t csz = lua_tointeger(L, 2);

  auto ofs = std::ofstream(block_fn);
  std::size_t n = 0;

  while (n < csz) {
    std::size_t w = csz - n;
    if (w > sizeof buf) {
      w = sizeof buf;
    }
    if (!ofs) break;
    ofs.write(buf, w);
    if (!ofs) break;
    n += w;
  }

  ofs.close();

  lua_pushinteger(L, n);
  return 1;
}

static const struct luaL_Reg regns [] = {
  {"ncm_add1", ncm_add1},
  {"fs_space", ncm_fs_space},
  {"fs_hash_value", ncm_fs_hash_value},
  {"int_to_hex64", ncm_int_to_hex64},
  {"create_file", ncm_create_file},
  {NULL, NULL}  /* sentinel */
};

extern "C" int luaopen_ncmcpp (lua_State *L) {
  lua_newtable(L);
  luaL_setfuncs(L, regns, 0);
  return 1;
}

#if 0
int main()
{
    const auto dirs = { "/dev/null", "/tmp", "/home", "/null" };
    print_space_info(dirs);
}
#endif
