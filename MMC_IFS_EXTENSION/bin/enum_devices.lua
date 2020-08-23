require "service"                                                                       
                                                                                        
vehSvc="com.harman.service.VehicleConfig"                                               
                                                                                        
local vehPlatform = service.invoke(vehSvc, "getProperties", {props={"vehiclePlatform"}})

if(os.getenv("VARIANT_MARKET")== "NA" or os.getenv("VARIANT_MARKET")== "ECE") then                                                                                      
	if (vehPlatform.vehiclePlatform == "Fiat334") then                                      
	 		cmd = "ln -svP /etc/ipod_334.cfg /etc/ipod.cfg"	                              
	 		os.execute(cmd) 
	 		cmd = "ln -svP /etc/bt_ipod_334.cfg /etc/bt_ipod.cfg"	                              
	 		os.execute(cmd) 		                                                                                                                                       
	elseif (vehPlatform.vehiclePlatform == "Fiat520") then                                  
			cmd = "ln -svP /etc/ipod_520.cfg /etc/ipod.cfg"                                 
			os.execute(cmd)
			cmd = "ln -svP /etc/bt_ipod_520.cfg /etc/bt_ipod.cfg"	                              
	 		os.execute(cmd)                                                                                                                                         
	else                                                                                                                                                     	                                                                  
	end
end                                                                                     