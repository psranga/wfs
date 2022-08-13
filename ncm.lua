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
  local preferred_fn = chunk_pfx .. '.r'

  local pdir = find_best_local_dir(csz, qosreq)
  if pdir == nil then return nil end

  local block_fn = reserve_fallocate(pdir, csz, preferred_fn)
  if block_fn == nil then return nil end
  -- assert(filesize(block_fn) == csz)

  local r = {}
  r.errno = 0
  r.blockid = block_fn
  return r
end

function reserve_fallocate(pdir, csz, preferred_fn)
  local block_fn = pdir .. '/' .. preferred_fn
  local nbytes_allocd = ncmcpp.create_file(block_fn, csz)
  if nbytes_allocd >= csz then
    return block_fn
  else
    return nil
  end
end

function find_best_local_dir(csz, qosreq)
  for i, cand_pdir in ipairs(pdirs) do
    local a = space_in_dir(cand_pdir)
    if a ~= nil and a > csz then return cand_pdir end
  end
  return nil
end

function make_chunk_pfx(fn, cbegin, cend)
  local s = fn .. '-' .. ncmcpp.int_to_hex64(cbegin) .. '-' .. ncmcpp.int_to_hex64(cend)
  return s
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

_printt_stats = {PASS=0, FAIL=0, DONTCARE=0}
function printt(val, checker)
  local res = 'PASS'
  if checker then
    if checker(val) ~= true then res = 'FAIL' end
  else
    res = 'DONTCARE'
  end
  _printt_stats[res] = _printt_stats[res] + 1
  print(val, '->', res)
end

printt(space_in_dir("/var"), function(x) return x > 0 end)
printt(ncmcpp.fs_hash_value("/var"))
printt(ncmcpp.int_to_hex64(64))
printt(ncmcpp.int_to_hex64(100))
printt(ncmcpp.int_to_hex64("100"), function(s) return s == '0x0000000000000064' end)
printt(ncmcpp.int_to_hex64("-1"), function(s) return s == '0xffffffffffffffff' end)
printt(ncmcpp.int_to_hex64("-2"), function(s) return s == '0xfffffffffffffffe' end)
printt(make_chunk_pfx('abcd.jpg', 0, 1024))
printt(ncmcpp.fs_hash_value(make_chunk_pfx('abcd.jpg', 0, 1024)))
printt(ncmcpp.fs_hash_value(make_chunk_pfx('abcd.jpg', 0, 1024)))
printt(ncmcpp.fs_hash_value(make_chunk_pfx('abcd.jpg', 0, 1023)))
printt(ncmcpp.fs_hash_value(make_chunk_pfx('abce.jpg', 0, 1024)))

local bytes_written = ncmcpp.create_file("/tmp/ac", 1048576)
printt(bytes_written)

local block_id = reserve_fallocate("/tmp", 1048576, "ac")
if block_id ~= nil then printt(block_id) else printt('error reserve_fallocate') end

local block_id = reserve_fallocate("/tmp", 1048576, "ac")
if block_id ~= nil then printt(block_id) else printt('error reserve_fallocate') end

print('reservefor ......')
pdirs = {'/tmp', '/var/tmp'}
local r = cm_reservefor {fn="ac", cbegin=0, cend=1024*1024, pubsum='0', mysum='0', qosreq=''}
if r ~= nil then
  printt(r.errno, function(x) return x == 0 end)
  printt(r.blockid, function(s) return #s > 0 end)
else
  printt('nil')
end
print('....... reservefor')
assert(_printt_stats['FAIL'] == 0)
