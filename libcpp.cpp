#include <iostream>
#include <fstream>
#include <filesystem>
#include <cstdint>
#include <string>

using std::string;

#if 0
#define FMT_HEADER_ONLY
#include "fmt/core.h"
#endif

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

namespace libcpp {
namespace internal {

std::string int_to_hex64(std::uint64_t n) {
  std::ostringstream os;
  os << "0x" << std::setbase(16) << std::setw(16) << std::setfill('0') << n << std::flush;
  return std::move(os.str());
}

} // namespace internal
} // namespace libcpp

namespace libcpp {

using namespace internal;

int fs_space(lua_State* L) {
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

int fs_hash_value(lua_State* L) {
  using std::filesystem::hash_value;
  using std::filesystem::path;

  const char *pn = lua_tostring(L, 1);  // any path.
  if (pn == 0) return 0;

  const std::size_t h = hash_value(path(pn));

  lua_pushstring(L, int_to_hex64(h).c_str());

  return 1;
}

int fs_file_size(lua_State* L) {
  using std::filesystem::file_size;
  using std::filesystem::path;

  const char *pn = lua_tostring(L, 1);  // any path.
  if (pn == 0) return 0;

  const std::size_t l = file_size(path(pn));

  lua_pushinteger(L, l);

  return 1;
}

int fs_has_root_path(lua_State* L) {
  using std::filesystem::path;

  const char *pn = lua_tostring(L, 1);  // any path.
  if (pn == 0) return 0;

  const bool l = path(pn).has_root_path();

  lua_pushinteger(L, l);

  return 1;
}

int fs_root_path(lua_State* L) {
  using std::filesystem::path;

  const char *pn = lua_tostring(L, 1);  // any path.
  if (pn == 0) return 0;

  const string s = path(pn).root_path();
  lua_pushstring(L, s.c_str());

  return 1;
}

int fs_filename(lua_State* L) {
  using std::filesystem::path;

  const char *pn = lua_tostring(L, 1);  // any path.
  if (pn == 0) return 0;

  const string s = path(pn).filename();
  lua_pushstring(L, s.c_str());

  return 1;
}

int cpp_int_to_hex64(lua_State* L) {
  lua_Integer n = lua_tointeger(L, 1);
  lua_pushstring(L, int_to_hex64(n).c_str());
  return 1;
}

const struct luaL_Reg regns [] = {
  {"fs_space", fs_space},
  {"fs_hash_value", fs_hash_value},
  {"fs_file_size", fs_file_size},
  {"fs_has_root_path", fs_has_root_path},
  {"fs_root_path", fs_root_path},
  {"fs_filename", fs_filename},
  {"cpp_int_to_hex64", cpp_int_to_hex64},
  {NULL, NULL}  /* sentinel */
};

} // namespace libcpp

extern "C" int luaopen_ncmcpp (lua_State *L) {
  lua_newtable(L);
  luaL_setfuncs(L, libcpp::regns, 0);
  return 1;
}
