--following utilities will be started on SD or USB pluggin
--1. MonitorProcesses
--2. HCP client
--following utilities will be stoped on ejection
--1. MonitorProcesses

local pps = require "pps"
local mcd = require "mcd"
local timer = require "timer"
local mcdInsertRule_1 = "CPULOGGER"
local mcdInsertRule_2 = "HCPClient_ON"
local mcdEjectRule = "EJECTED"
local setMonProcDevicePath
local alreadyLogging = 0
local flagPath = "/usr/var/hcp/VEHICLE_TRUE"

local function beginLogging(path)
   if alreadyLogging == 0 then
      alreadyLogging = 1
	  
      setMonProcDevicePath = path
      -----local cpulogger
      print("Begin cpulogger, logging to: ", path)
      --print "Entered Begin logging from Lua script\n"

      --------- Executing the logging script-----

      os.execute("sh /fs/mmc0/app/bin/cpulogger.sh")  
   end
end

--function for determining if radio is bench or vehicle mode.
function carOrBench()
	-- Check if flag exists. if so, skip entirelly.
	flag = file_check(flagPath)
	if flag == false then
		-- No flag, lets check EngRPM
		EngRPM = readEngRPM()
		print("Engine RPM is : "..EngRPM)
		
		-- After getting EngRPM value take proper action.
		if (EngRPM == '0' or EngRPM == '65535') then
			-- Not a vehicle lets do nothing
			print("Not a vehicle. Skipping.")
		else
			print("Vehicle Found!")
			
			-- Creating flag
			os.execute("touch "..flagPath)
			print("Flag Created")
		end
	else
		-- File exists.. 
		print("Flag Exists Already")
	end
end

-- Function returns value of EngRPM from /pps/can/vehstat
-- TODO: change to generalized form.?
function readEngRPM()
	print("Reading pps/can/vehstat for EngRPM")
	
	local vehstat = pps.open("/pps/can/vehstat", "r")
	if vehstat then
		local t = vehstat:read("*t")
		vehstat:close()
		if t.EngRPM then
			return t.EngRPM
		end
	end
end

-- Function checks for existance of a file.
-- file_name : Path of file to check if exists.
function file_check(file_name)
	print("Checking for file"..file_name)
	
	local file_found=io.open(file_name, "r")      
	if file_found == nil then
		return false
	else
		return true
	end
	
	return file_found
end

--function for executing startHCP client
local function startHCPClient()
    print "cpulogger:Entered start HCPClient logging from Lua script\n"
    os.execute("sh /fs/mmc0/app/bin/runhcpclient.sh")
end

local function stopLogging(path)
   if path == setMonProcDevicePath then
      print ("Stopped logging to path:", path)
      os.execute("slay MonitorProcesses")
      os.execute("slay dumper")
	  -- Reset logging flag
	  alreadyLogging = 0
   end
end   
 
--Set Notfications for SD INSERTION
--print "calling mcd.notify\n"
mcd.notify(mcdInsertRule_1,beginLogging)
mcd.notify(mcdInsertRule_2,startHCPClient)
mcd.notify(mcdEjectRule,stopLogging)

--print "called mcd.notify\n"

startupTimer = timer.new(carOrBench)
startupTimer:start(120000,1)
