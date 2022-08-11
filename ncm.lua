-- (network) chunk manager.
-- chunk = <filename>\n<begin>\n<end>\n
--
--[[

RESERVEFOR:

  RESERVEFOR\n
  fn: fn\n <-- base64 if not a char possible to type on ANSI US keyb
  begin: begin\n
  end: end\n
  pubsum: public-checksum (MAC)\n
  mysum: private checksum (HMAC)\n
  \n

  blockid: id
  errno: errno
  errno1: suberrorlevel
  errno2: sub-suberrorlevel
  perror: perror

STAGE:

  STAGE\n
  blockid: id\n
  sz: sz\n
  mysum: HMAC\n
  pubsum: MAC\n
  \n
  <raw data>

  mysum: HMAC
  pubsum: MAC
  errno: errno

COMMITIF:

  COMMITIF\n
  fn: fn\n
  begin: begin\n
  end: end\n
  blockid: id
  pubsum: MAC
  mysum: HMAC

COMMITMANY:

  COMMITMANY\n
  0 fn: fn\n
  0 begin: begin\n
  0 end: end\n
  0 blockid: id
  0 pubsum: MAC
  0 mysum: HMAC
  1 fn: fn\n
  1 begin: begin\n
  1 end: ...
  ...
  \n

Output:

  errno:
  0 mysum: HMAC
  0 pubsub: MAC
  0 errno: errno

--]]

--[[
RESERVEFOR:

  RESERVEFOR\n
  fn: fn\n <-- base64 if not a char possible to type on ANSI US keyb
  begin: begin\n
  end: end\n
  pubsum: public-checksum (MAC)\n
  mysum: private checksum (HMAC)\n
  \n

  blockid: id
  errno: errno
  errno1: suberrorlevel
  errno2: sub-suberrorlevel
  perror: perror
--]]

-- list of directories in which we can create files.
pdirs = {}

luaopen_ncmcpp = package.loadlib("/home/ranga/wip/wfs/libncmcpp.so", "luaopen_ncmcpp")
ncmcpp = luaopen_ncmcpp()

function cm_reservefor(req) -- fn, cbegin, cend, pubsum, mysum)
  local fn = req.fn
  local cbegin = req.cbegin
  local cend = req.cend
  local pubsum = req.pubsum
  local mysum = req.mysum
  local qosreq = req.qosreq

  assert(cend > cbegin)

  local csz = cend - cbegin
  if csz < 0 then return cm_error("bad args: cend <= cbegin") end

  -- TODO: factor out into a function/module.
  local chunk_pfx = make_chunk_pfx(fn, cbegin, cend)
  local pdir = find_best_local_dir(csz, qosreq)
  local block_fn = reserve_fallocate(pdir, csz)
  assert(filesize(block_fn) == csz)

  local r = {}
  r.errno = 0
  r.blockid = block_fn
  return r
end

function reserve_fallocate(pdir, csz, preferred_fn)
end

function find_best_local_dir(csz, qosreq)
  for i, cand_pdir in ipairs(pdirs) do
    local a = space_in_dir(cand_pdir)
    if a ~= nil and a > csz then return cand_pdir end
  end
  return nil
end

function make_chunk_pfx(fn, cbegin, cend)
  local s = fn .. '-' .. int_to_hex64(cbegin) .. '-' .. int_to_hex64(cend)
end

-- dn is a directory path.
function space_in_dir(dn)
  local si = ncmcpp.fs_space(dn)
  if si then return si.available else return nil end

  function test_00()
    x = ncmcpp.ncm_fs_space("/var")
    print(x.available)
    for k, v in pairs(x) do
      print('k: ', k, ' v: ', v)
    end
  end

end

print(space_in_dir("/var"))
print(ncmcpp.fs_hash_value("/var"))

