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

namespace wfsint {

std::string int_to_hex64(std::uint64_t n) {
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

} // namespace wfsint

namespace wfslua {

using namespace wfsint;

int ncm_fs_space(lua_State* L) {
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

int ncm_fs_hash_value(lua_State* L) {
  using std::filesystem::hash_value;
  using std::filesystem::path;

  const char *pn = lua_tostring(L, 1);  // any path.
  if (pn == 0) return 0;

  const std::size_t h = hash_value(path(pn));

  lua_pushstring(L, int_to_hex64(h).c_str());

  return 1;
}

int ncm_fs_file_size(lua_State* L) {
  using std::filesystem::file_size;
  using std::filesystem::path;

  const char *pn = lua_tostring(L, 1);  // any path.
  if (pn == 0) return 0;

  const std::size_t l = file_size(path(pn));

  lua_pushinteger(L, l);

  return 1;
}

int ncm_int_to_hex64(lua_State* L) {
  lua_Integer n = lua_tointeger(L, 1);
  lua_pushstring(L, int_to_hex64(n).c_str());
  return 1;
}

int ncm_create_new_file(lua_State* L) {
  char buf[4096];

  const char* block_fn = lua_tostring(L, 1);
  std::size_t csz = lua_tointeger(L, 2);

  // TODO: error if the file exists.
  std::error_code ec;
  const auto not_found_status =
    std::filesystem::file_status(std::filesystem::file_type::not_found);
  const auto fstatus = std::filesystem::status(block_fn, ec);
  if (fstatus != not_found_status) return 0;

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

const struct luaL_Reg regns [] = {
  {"fs_space", ncm_fs_space},
  {"fs_hash_value", ncm_fs_hash_value},
  {"fs_file_size", ncm_fs_file_size},
  {"int_to_hex64", ncm_int_to_hex64},
  {"create_new_file", ncm_create_new_file},
  {NULL, NULL}  /* sentinel */
};

} // namespace wfslua

extern "C" int luaopen_ncmcpp (lua_State *L) {
  lua_newtable(L);
  luaL_setfuncs(L, wfslua::regns, 0);
  return 1;
}
