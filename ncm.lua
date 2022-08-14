-- local chunk manager.
-- cm_reservefor: fn, csz, csum, qosreq -> blockid
-- cm_stage: blockid, csz, csum, data -> blockid
-- cm_commitif: blockid, fn, csz, csum -> fn

-- list of directories in which we can create files.
local std = require('stdlib')

local pdirs = {'/tmp', '/var/tmp'}
local blockids = {} -- mapping from blockid to underlying filename

function cm_reservefor(req) -- fn, csz, csum, qosreq -> blockid
  local me = 'reservefor'
  local fn = req.fn
  local cbegin = req.cbegin
  local cend = req.cend
  local pubsum = req.pubsum
  local mysum = req.mysum
  local qosreq = req.qosreq
  std.dlog(me, 'req: ', req)

  assert(cend > cbegin)

  local csz = cend - cbegin
  if csz < 0 then return cm_error("bad args: cend <= cbegin") end

  -- TODO: factor out into a function/module.
  local chunk_pfx = make_chunk_pfx(fn, cbegin, cend)
  local preferred_fn = chunk_pfx .. '.r'

  local pdir = find_best_local_dir(csz, qosreq)
  if pdir == nil then return nil end
  dlog2(me, 'pdir: ', pdir)

  local block_fn = reserve_fallocate(pdir, csz, preferred_fn)
  if block_fn == nil then return nil end
  -- assert(std.file_size(block_fn) == csz)

  local r = {}
  r.errno = 0
  r.blockid = chunk_pfx
  blockids[r.blockid] = {pdir=pdir, reserved_fn=preferred_fn, block_fn=block_fn}
  return r
end

function cm_stage(req) -- blockid, csz, csum, data -> blockid
  local me = 'stage'
  local blockid = req.blockid
  local cbegin = req.cbegin
  local cend = req.cend -- yes, the caller needs to keep around previous info.
  local pubsum = req.pubsum
  local mysum = req.mysum
  local data = req.data
  local rcopy = req; rcopy.data = '<' .. #req.data .. ' bytes>'
  std.dlog(me, 'req: ', rcopy)

  local csz = cend - cbegin
  if csz < 0 then return nil end

  if #data ~= csz then return nil end

  -- done with checking preconditions

  local blockinfo = blockids[blockid]
  if blockinfo == nil then return nil end

  local block_fn = blockinfo.block_fn
  if block_fn == nil then return nil end

  std.dlog2(me, 'block_fn: ', block_fn)

  local fs = std.file_size(block_fn)
  std.dlog2(me, 'fs: ', fs)
  if fs ~= csz then return nil end

  local fh = io.open(block_fn, 'wb')
  if fh == nil then return nil end

  local ior, msg, ecode = fh:write(data)
  if ior == nil then return nil end

  local ior, msg, ecode = fh:close()
  if ior == nil then return nil end

  local r = {}
  r.blockid = blockid
  r.errno = 0
  r.errorinfo = {errorcode=ecode, errormsg=msg}
  return r
end

function cm_commitif(req) -- blockid, fn, csz, csum -> fn
  function start_txn() end  -- TODO: actually do these.
  function end_txn() end

  local me = 'commitif'
  local fn = req.fn
  local blockid = req.blockid
  local cbegin = req.cbegin
  local cend = req.cend
  local pubsum = req.pubsum
  local mysum = req.mysum
  std.dlog(me, 'req: ', req)

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
  std.dlog2(me, 'orig_fn: ', orig_fn, ' new_fn: ', new_fn, ' block_fn: ', block_fn)

  if orig_fn ~= block_fn then return nil end

  -- lol caller needs to keep around previous info.
  local fs = std.file_size(block_fn)
  std.dlog2(me, 'fs: ', fs)
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

function reserve_fallocate(pdir, csz, preferred_fn)
  local block_fn = pdir .. '/' .. preferred_fn
  dlog('falloc', 'block_fn: ', block_fn, ' csz: ', csz)
  local nbytes_allocd = std.cpp.create_new_file(block_fn, csz)
  dlog2('falloc', 'nbytes_allocd: ', nbytes_allocd)
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
  local s = fn .. '-' .. std.int_to_hex64(cbegin) .. '-' .. std.int_to_hex64(cend)
  return s
end

-- --------------------------------------------------------------------

local M = {}
M.cm_reservefor = cm_reservefor
M.cm_stage = cm_stage
M.cm_commitif = cm_commitif
M.CmClient = CmClient
return M
