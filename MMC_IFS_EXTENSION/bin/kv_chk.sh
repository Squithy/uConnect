#!/usr/bin/lua

local MIN_DB_FILE_SIZE = 4
local DB_FILE = "/usr/var/qdb/key_value"

local lfs = require "lfs"

local fsize,e = lfs.attributes(DB_FILE,"size")

if e then 
   print("p.sh: lfs.attributes error - ", e)
   os.exit(1) 
end

if (type(fsize) == "number") and (fsize < MIN_DB_FILE_SIZE) then
   if not os.remove(DB_FILE) then
      print("kv_chk.sh: os.remove error")
      os.exit(2)
   else
      print("kv_chk.sh: file "..DB_FILE.." detected at less than "..MIN_DB_FILE_SIZE.." so it was deleted (CMC-587)")
   end 
end
