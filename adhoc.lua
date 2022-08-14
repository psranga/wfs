local std = require('stdlib')
local printt = std.printt
local dlog1 = std.dlog1
local dlog2 = std.dlog2

local cm = require('ncm')
cm_reservefor = cm.cm_reservefor
cm_stage = cm.cm_stage
cm_commitif = cm.cm_commitif
CmClient = cm.CmClient

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
