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
local stdlib = require('stdlib')
function start_txn() end
function end_txn() end

pdirs = {}
blockids = {} -- mapping from blockid to underlying filename

luaopen_ncmcpp = package.loadlib("/home/ranga/wip/wfs/libncmcpp.so", "luaopen_ncmcpp")
ncmcpp = luaopen_ncmcpp()

--[[
STAGE:

  STAGE\n
  blockid: id\n
  csz: csz\n
  mysum: HMAC\n
  pubsum: MAC\n
  \n
  <raw data>

  mysum: HMAC
  pubsum: MAC
  errno: errno
--]]
function cm_stage(req) -- blockid, csz, pubsum, mysum, data)
  local me = 'stage'
  local blockid = req.blockid
  local cbegin = req.cbegin
  local cend = req.cend -- yes, the caller needs to keep around previous info.
  local pubsum = req.pubsum
  local mysum = req.mysum
  local data = req.data
  local rcopy = req; rcopy.data = '<' .. #req.data .. ' bytes>'
  stdlib.dlog(me, 'req: ', rcopy)

  local csz = cend - cbegin
  if csz < 0 then return nil end

  if #data ~= csz then return nil end

  -- done with checking preconditions

  local blockinfo = blockids[blockid]
  if blockinfo == nil then return nil end

  local block_fn = blockinfo.block_fn
  if block_fn == nil then return nil end

  stdlib.dlog2(me, 'block_fn: ', block_fn)

  local fs = file_size(block_fn)
  stdlib.dlog2(me, 'fs: ', fs)
  if fs ~= csz then return nil end

  local fh = io.open(block_fn, 'wb')
  if fh == nil then return nil end

  local ior, msg, ecode = fh:write(data)
  if ior == nil then return nil end

  local ior, msg, ecode = fh:close()
  if ior == nil then return nil end

  local r = {}
  r.errno = 0
  r.errorinfo = {errorcode=ecode, errormsg=msg}
  return r
end

--[[
COMMITIF:

  COMMITIF\n
  fn: fn\n
  begin: begin\n
  end: end\n
  blockid: id
  pubsum: MAC
  mysum: HMAC
--]]
-- rename the file in blockids[blockid] to based on fn.
function cm_commitif(req) -- blockid, fn, csz, pubsum, mysum
  local me = 'commitif'
  local fn = req.fn
  local blockid = req.blockid
  local cbegin = req.cbegin
  local cend = req.cend
  local pubsum = req.pubsum
  local mysum = req.mysum
  stdlib.dlog(me, 'req: ', req)

  local csz = cend - cbegin
  if csz < 0 then return nil end

  local blockinfo = blockids[blockid]
  if blockinfo == nil then return nil end

  local block_fn = blockinfo.block_fn
  if block_fn == nil then return nil end

  local reserved_fn = blockinfo.reserved_fn
  local pdir = blockinfo.pdir

  -- self checks. TODO: consider restarting the server if this happens?
  -- why don't have the info the user sent us before? bail.
  if reserved_fn == nil then return nil end
  if pdir == nil then return nil end

  local chunk_pfx = make_chunk_pfx(fn, cbegin, cend)
  -- avoid using any absolute paths as is from data structs.
  -- reconstruct any absolute paths using info saved from before.
  local orig_fn = pdir .. '/' .. reserved_fn  -- from cm_reservefor().
  local new_fn = pdir .. '/' .. chunk_pfx
  stdlib.dlog2(me, 'orig_fn: ', orig_fn, ' new_fn: ', new_fn, ' block_fn: ', block_fn)

  if orig_fn ~= block_fn then return nil end

  -- lol caller needs to keep around previous info.
  local fs = file_size(block_fn)
  stdlib.dlog2(me, 'fs: ', fs)
  if fs ~= csz then return nil end

  start_txn()

  local ior, msg, ecode = os.rename(orig_fn, new_fn)
  if ior == nil then return nil end

  -- clear the block from the list of blocks that can be staged.
  -- ideally this and the rename should be both in a single txn.
  blockids[blockid] = nil

  end_txn()

  local r = {}
  r.errno = 0
  r.fn = fn
  return r
end


function cm_reservefor(req) -- fn, cbegin, cend, pubsum, mysum)
  local me = 'reservefor'
  local fn = req.fn
  local cbegin = req.cbegin
  local cend = req.cend
  local pubsum = req.pubsum
  local mysum = req.mysum
  local qosreq = req.qosreq
  stdlib.dlog(me, 'req: ', req)

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
  -- assert(file_size(block_fn) == csz)

  local r = {}
  r.errno = 0
  r.blockid = chunk_pfx
  blockids[r.blockid] = {pdir=pdir, reserved_fn=preferred_fn, block_fn=block_fn}
  return r
end

function reserve_fallocate(pdir, csz, preferred_fn)
  local block_fn = pdir .. '/' .. preferred_fn
  local nbytes_allocd = ncmcpp.create_new_file(block_fn, csz)
  if nbytes_allocd == nil then return nil end

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


function file_size(fn)
  return ncmcpp.fs_file_size(fn)
end

-- --------------------------------------------------------------------

_printt_stats = {PASS=0, FAIL=0, DONTCARE=0}
function printt(val, checker)
  local res = 'PASS'
  if checker then
    if checker(val) ~= true then res = 'FAIL' end
  else
    if val == nil then res = 'FAIL' else res = 'DONTCARE' end
  end
  _printt_stats[res] = _printt_stats[res] + 1
  print(stdlib.dlog_snippet(val), '->', res)
  if res == 'PASS' then return true, val else return false end
end

--[[
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

local of = io.open("/tmp/ac", "wb")
of:close()

local bytes_written = ncmcpp.create_new_file("/tmp/ac", 1048576)
printt(bytes_written, function(x) return x == nil end)

os.remove("/tmp/ac")
local block_id = reserve_fallocate("/tmp", 1048576, "ac")
if block_id ~= nil then printt(block_id) else printt('error reserve_fallocate') end
--]]

-- Tests using the external API.
print('reservefor ......')
pdirs = {'/tmp', '/var/tmp'}
os.remove('/tmp/ac-0x0000000000000000-0x0000000000100000.r')

local req1 = {fn="ac", cbegin=0, cend=1024*1024, pubsum='0', mysum='0', qosreq=''}
local rsp1 = cm_reservefor(req1)
printt(rsp1,
  function(r)
    if r == nil then return false end
    return printt(r.errno, function(x) return x == 0 end) and
      printt(r.blockid, function(s) return #s > 0 end)
  end
)
print('....... reservefor')

-- blockid, csz, pubsum, mysum, data)
assert(_printt_stats['FAIL'] == 0)
print('stage ......')
local req2 = {blockid=rsp1.blockid, cbegin=req1.cbegin, cend=req1.cend, pubsum=req1.pubsum, mysum=req1.mysum}
local s1 = rep('0123456789abcdef', 128)
req2.data = rep(s1, 512)
assert(#req2.data == 1024*1024)
local rsp2 = cm_stage(req2)
printt(rsp2)
print('........ stage')

assert(_printt_stats['FAIL'] == 0)
print('stage2 ......')
local req2 = {blockid=rsp1.blockid, cbegin=req1.cbegin, cend=req1.cend, pubsum=req1.pubsum, mysum=req1.mysum}
local s1 = rep('0123456789abcde\n', 128)
req2.data = rep(s1, 512)
-- assert(#req2.data == 1024*1024)
local rsp2 = cm_stage(req2)
printt(rsp2)
print('........ stage2')

assert(_printt_stats['FAIL'] == 0)
print('commitif ......')
local req3 = {fn='ad', blockid=rsp1.blockid, cbegin=req1.cbegin, cend=req1.cend, pubsum=req1.pubsum, mysum=req1.mysum}
local rsp3 = cm_commitif(req3)
printt(rsp3)
print('........ commitif')

assert(_printt_stats['FAIL'] == 0)
