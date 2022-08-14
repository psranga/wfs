local std = require('stdlib')
local printt = std.printt
local dlog1 = std.dlog1
local dlog2 = std.dlog2

local cm = require('lcm')
cm_reservefor = cm.lcm_reservefor
cm_stage = cm.lcm_stage
cm_commitif = cm.lcm_commitif

--[[
local wfs = require('wfs')
wfs_upload_file = wfs.wfs_upload_file
wfs_download_file = wfs.wfs_download_file
wfs_stream_upload_file = wfs.wfs_stream_upload_file
wfs_stream_download_file = wfs.wfs_stream_download_file

local cmclient = CmClient:new()

local buf = rep(rep('0123456789abcde\n', 100), 20)
std.set_file_contents('/dev/shm/ad', buf)
os.remove('/tmp/ax-0x0000000000000000-0x0000000000007d00')
os.remove('/tmp/ax-0x0000000000000000-0x0000000000007d00.r')
printt(wfs_upload_file(cmclient, '/dev/shm/ad', 'ax'), expect_true)
--]]

printt(is_bare_filename('/dev/shm/ad'), expect_false)
printt(is_bare_filename('ad'), expect_true)
printt(std.cpp.fs_root_path('ad'), expect_string(''))
printt(std.cpp.fs_has_root_path('ad'), expect_zero)

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
