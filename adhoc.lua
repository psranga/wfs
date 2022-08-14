local std = require('stdlib')
local printt = std.printt
local dlog1 = std.dlog1
local dlog2 = std.dlog2

local Lcm = require('lcm')

local modwfs = require('wfs')
-- local lcm_remotes = discover_lcm_remotes()
local wfs = modwfs.SimpleWfs:new(os.getenv('LCM_REMOTES'))
wfs.cm = lcm

--[[
wfs_upload_file = wfs.wfs_upload_file
wfs_download_file = wfs.wfs_download_file
wfs_stream_upload_file = wfs.wfs_stream_upload_file
wfs_stream_download_file = wfs.wfs_stream_download_file
--]]

local buf = rep(rep('0123456789abcde\n', 100), 20)  -- 2000*16-bytes = 32000
std.set_file_contents('/dev/shm/ad', buf)
os.remove('/tmp/ax-0x0000000000000000-0x0000000000007d00')
os.remove('/tmp/ax-0x0000000000000000-0x0000000000007d00.r')

printt(wfs:upload_file('/dev/shm/ad', 'ax'), expect_true)
