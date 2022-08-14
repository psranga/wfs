local std = require('stdlib')
local ncmcpp = std.ncmcpp

local cm = require('ncm')
local printt = std.printt
local dlog1 = std.dlog1
local dlog2 = std.dlog2

function wfs_upload_file(cmclient, lfn, nfn)
  -- local reserveforblock = cm.cm_reservefor
  -- local stageblock = cm.cm_stage
  -- local commitblockif = cm.cm_commitif

  -- reserve, stage, copy the file.
  local me = 'upload'
  dlog(me, 'lfn: ', lfn, ' nfn: ', nfn)
  if not is_bare_filename(nfn) then return nil end

  local fs = file_size(lfn)
  dlog2(me, 'lfn: ', lfn, ' #lfn: ', fs)

  local req1 = {fn=nfn, cbegin=0, cend=file_size(lfn), pubsum='0', mysum='0', qosreq=''}
  dlog2(me, 'req1: ', req1)
  local rsp1 = cmclient:reserveforblock(req1)
  dlog2(me, 'rsp1: ', rsp1)
  if rsp1 == nil or rsp1.errno ~= 0 or rsp1.blockid == nil then return nil end

  -- blockid, csz, pubsum, mysum, data)
  local req2 = {blockid=rsp1.blockid, cbegin=req1.cbegin, cend=req1.cend, pubsum=req1.pubsum, mysum=req1.mysum}
  dlog2(me, 'req2: ', req2)
  req2.data = std.get_file_contents(lfn)
  dlog2(me, '#data: ', #req2.data)
  local rsp2 = cmclient:stageblock(req2)
  dlog2(me, 'rsp2: ', rsp2)

  local req3 = {fn=nfn, blockid=rsp1.blockid, cbegin=req1.cbegin, cend=req1.cend, pubsum=req1.pubsum, mysum=req1.mysum}
  dlog2(me, 'req2: ', req3)
  local rsp3 = cmclient:commitblockif(req3)
  dlog2(me, 'rsp2: ', rsp3)

  if rsp3.errno ~= 0 then return nil end
  return true
end

function wfs_download_file(lfn, nfn)
  local me = 'dnload'
end

function wfs_stream_upload_file(lfn, cb)
  local me = 'upload2'
end

function wfs_stream_download_file(lfn, cb)
  local me = 'dnload2'
end

local M = {}
M.wfs_upload_file = wfs_upload_file
M.wfs_download_file = wfs_download_file
M.wfs_stream_upload_file = wfs_stream_upload_file
M.wfs_stream_download_file = wfs_stream_download_file
return M
