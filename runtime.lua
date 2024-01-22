--[[
	Samsung Commercial Display Runtime

	2 Connectivity types;  Direct Serial Connection and Ethernet
	Both use the same commands
	Based on user set Property "Connection Type"  the communication engine and send and receive functions will be defined to use one or the other.

	The command parsing, processsing, and input handlers will call the same functions so Send needs to have the same inputs in both builds.
]]

-- Control aliases
Status = Controls.Status

-- Variables and flags
DebugTx=false
DebugRx=false
DebugFunction=false
DebugPrint=Properties["Debug Print"].Value

-- Timers, tables, and constants
StatusState = { OK = 0, COMPROMISED = 1, FAULT = 2, NOTPRESENT = 3, MISSING = 4, INITIALIZING = 5 }
Heartbeat = Timer.New()
PowerupTimer = Timer.New()
VolumeDebounce = Timer.New()
PowerupCount = 0
PollRate = Properties["Poll Interval"].Value
Timeout = PollRate + 10
BufferLength = 1024
ConnectionType = Properties["Connection Type"].Value
DataBuffer = ""
CommandQueue = {}
CommandProcessing = false
--Internal command timeout
CommandTimeout = 5
CommunicationTimer = Timer.New()
PowerOnDebounceTime = 20
PowerOnDebounce = false
TimeoutCount = 0
ActiveInput = 1
for i=1,#Controls['InputButtons'] do
	if Controls['InputButtons'][i].Boolean then
		ActiveInput = i
	end
end

--Hide controls that are just for pins
Controls["ModelNumber"].IsInvisible=true
Controls["PanelType"].IsInvisible=true

--[[
	Request Command Set
	Named reference to each of the command objects used here in
	Note commands are in decimal here, translation to hex is done in Send()
]]
local Request = {
	Status={Command=0,Data={}},
	SerialNumber={Command=11,Data={}},
	SWVersion={Command=14,Data={}},
	ModelNumber={Command=16,Data={}},
	ModelName={Command=138,Data={}},
	DeviceName={Command=103,Data={}},
	MACAddress={Command=27,Data={129}},

	PowerStatus={Command=17,Data={}},
	PowerOn={Command=17,Data={1}},
	PowerOff={Command=17,Data={0}},
	Reboot={Command=17,Data={2}},
	
	PanelStatus={Command=249,Data={}},
	PanelOn={Command=249,Data={0}},
	PanelOff={Command=249,Data={1}},
	
	DisplayStatus={Command=13,Data={}},
	InputStatus={Command=20,Data={}},
	InputSet={Command=20,Data={}},  

	SoundStatus={Command=9,Data={}},
	VolumeStatus={Command=18,Data={}},
	VolumeSet={Command=18,Data={0}},
	VolumeUp={Command=98,Data={0}},
	VolumeDown={Command=98,Data={1}},
	MuteStatus={Command=19,Data={}},
	MuteOn={Command=19,Data={1}},
	MuteOff={Command=19,Data={0}}
}

-- Helper functions
-- A function to determine common print statement scenarios for troubleshooting
function SetupDebugPrint()
	if DebugPrint=="Tx/Rx" then
		DebugTx,DebugRx=true,true
	elseif DebugPrint=="Tx" then
		DebugTx=true
	elseif DebugPrint=="Rx" then
		DebugRx=true
	elseif DebugPrint=="Function Calls" then
		DebugFunction=true
	elseif DebugPrint=="All" then
		DebugTx,DebugRx,DebugFunction=true,true,true
	end
end

-- A function to clear controls/flags/variables and clears tables
function ClearVariables()
	if DebugFunction then print("ClearVariables() Called") end
	Request["InputSet"]["Data"][1]=1
	Controls["SerialNumber"].String = ""
	Controls["DeviceFirmware"].String = ""
	Controls["ModelNumber"].String = ""
	Controls["ModelName"].String = ""
	Controls["DeviceName"].String = ""
	Controls["MACAddress"].String = ""
	DataBuffer = ""
	CommandQueue = {}
end

--Reset any of the "Unavailable" data;  Will cause a momentary colision that will resolve itself the customer names the device "Unavailable"
function ClearUnavailableData()
	if DebugFunction then print("ClearUnavailableData() Called") end
	-- If data was unavailable reset it; the next poll loop will test for it again
	for i,ctrl in ipairs({ "SerialNumber", "DeviceFirmware", "ModelNumber", "ModelName", "DeviceName", "MACAddress" }) do
		if(Controls[ctrl].String == "Unavailable")then
			Controls[ctrl].String = ""
		end
	end
end

-- Update the Status control
function ReportStatus(state,msg)
	if DebugFunction then print("ReportStatus() Called: "..state.." - "..msg) end
	--Dont report status changes immediately after power on
	if PowerOnDebounce == false then
		local msg=msg or ""
		Status.Value=StatusState[state]
		Status.String=msg
		--Show the power off state if we can't communicate
		if(state ~= "OK")then
			Controls["PowerStatus"].Value = 0
			Controls["PanelStatus"].Boolean = false
		end
	end
end

-- Interface will receive a lot of strings of hex bytes; Printing decimal values for easier debug
function PrintByteString(ByteString, header)
	if DebugFunction then print("PrintByteString() Called") end
	local result=header or ""
	if(ByteString:len()>0)then
		for i=1,ByteString:len() do
			result = result .. ByteString:byte(i) .. " "
		end
	end
	print( result )
end

-- Arrays of bytes may get used often; Printing decimal values for easier debug
function PrintByteArray(ByteArray, header)
	if DebugFunction then print("PrintByteArray() Called") end
	local result=header or ""
	if(#ByteArray>0)then
		for i=1,#ByteArray do
			result = result .. ByteArray[i] .. " "
		end
	end
	print( result )
end

-- Set the current input indicators
function SetActiveInput(index)
	if DebugFunction then print("SetActiveInputIndicator() Called") end
	if(index)then
		Controls["Input"].String = InputTypes[index].Name
		Controls["InputButtons"][ActiveInput].Value = false
		Controls["InputStatus"][ActiveInput].Value = false
		Controls["InputButtons"][index].Value = true
		Controls["InputStatus"][index].Value = true
		ActiveInput = index
	else
		Controls["Input"].String = "Unknown"
		Controls["InputButtons"][ActiveInput].Value = false
		Controls["InputStatus"][ActiveInput].Value = false
	end
end

--Parse a string from byte array
function ParseString(data)
	if DebugFunction then print("ParseString() Called") end
	local name = ""
	for i,byte in ipairs(data) do
		name = name .. string.char(byte)
	end
	return name
end

--A debounce timer on power up avoids reporting the TCP reset that occurs as ane error
function ClearDebounce()
	PowerOnDebounce = false
end


------ Communication Interfaces --------

-- Shared interface functions
function Init()
	if DebugFunction then print("Init() Called") end
	Disconnected()
	Connect()
end

function Connected()
	if DebugFunction then print("Connected() Called") end
	CommunicationTimer:Stop()
	Heartbeat:Start(PollRate)
	CommandProcessing = false
	SendNextCommand()
end

--Wrapper for setting the pwer level
function SetPowerLevel(val)
	--
	if val==1 and Controls["PowerStatus"].Value~=val then
		ClearUnavailableData()
		PowerupTimer:Stop()

	--If the display is being shut off, clear the buffer of commands
	--This prevents a hanging off command from immediately turn the display off on next power-on command
	elseif(val == 0)then
		CommandQueue = {}
	end
	Controls["PowerStatus"].Value = val
end

--[[  Communication format
	All commands are hex bytes of the format:
			Header   Command   DeviceID   DataLength   Val 1.......   CheckSum
			0xAA     0x??       0x??      0x??(int)    0x??0x??...     0x??
	Extended commands will have Val 1 be a SubCommand when sending
	Responses will contain an ACK/NACK as the first Val in the data section
	Checksum ignores Header byte
	Switching Device ID for 0xFE will cause the display to broadcast the command to all daisy chained serial connected displays, but won't respond.

	Both Serial and TCP mode must contain functions:
		Connect()
		Controls["PowerOn"].EventHandler() 
		And a receive handler that passes data to ParseData()
]]

-- Take a request object and queue it for sending.  Object format is of:
--  { Command=int, Data={int} }
--  ints must be between 0 and 255 for hex translation
--  Broadcast is a Boolean to determine if using Broadcast ID for this send
function Send(cmd, broadcast, sendImmediately)
	if DebugFunction then print("Send() Called") end
	local ID = Controls["DisplayID"].Value
	if(broadcast)then
		ID = 254
	end
	local value = "\xAA".. string.char( cmd.Command ) .. string.char( ID ) .. string.char( #cmd.Data )
	local checksum = cmd.Command + ID + #cmd.Data
	local i = 1

	while cmd.Data[i]~=nil do
		value = value .. string.char( cmd.Data[i] ) 
		checksum = checksum + cmd.Data[i]
		i=i+1
	end
	value = value .. string.char( checksum % 256 ) 

	--Check for if a command is already queued
	for i, val in ipairs(CommandQueue) do
		if(val == value)then
			--Some Commands should be sent immediately
			if sendImmediately then
				--remove other copies of a command and move to head of the queue
				table.remove(CommandQueue,i)
				if DebugTx then PrintByteString(value, "Sending: ") end
				table.insert(CommandQueue,1,value)
			end
			return
		end
	end
	--Queue the command if it wasn't found
	table.insert(CommandQueue,value)
	SendNextCommand()
end


--Timeout functionality
-- Close the current and start a new connection with the next command
-- This was included due to behaviour within the Samsung Serial; may be redundant check on TCP mode
CommunicationTimer.EventHandler = function()
	if DebugFunction then print("CommunicationTimer Event (timeout) Called") end
	ReportStatus("MISSING","Communication Timeout")
	CommunicationTimer:Stop()
	CommandProcessing = false
	SendNextCommand()
end 

--  Serial mode Command function  --
if ConnectionType == "Serial" then
	print("Serial Mode Initializing...")
	-- Create Serial Connection
	Samsung = SerialPorts[1]
	Baudrate, DataBits, Parity = 9600, 8, "N"

	--Send the display the next command off the top of the queue
	function SendNextCommand()
		if DebugFunction then print("SendNextCommand() Called") end
		if CommandProcessing then
			-- Do Nothing
		elseif #CommandQueue > 0 then
			CommandProcessing = true
			if DebugTx then PrintByteString(CommandQueue[1], "Sending: ") end
			Samsung:Write( table.remove(CommandQueue,1) )
			CommunicationTimer:Start(CommandTimeout)
		else
			CommunicationTimer:Stop()
		end
	end

	function Disconnected()
		if DebugFunction then print("Disconnected() Called") end
		CommunicationTimer:Stop() 
		CommandQueue = {}
		Heartbeat:Stop()
	end

	-- Clear old and open the socket, sending the next queued command
	function Connect()
		if DebugFunction then print("Connect() Called") end
		Samsung:Close()
		Samsung:Open(Baudrate, DataBits, Parity)
	end

	-- Handle events from the serial port
	Samsung.Connected = function(serialTable)
		if DebugFunction then print("Connected handler called Called") end
		ReportStatus("OK","")
		Connected()
	end

	Samsung.Reconnect = function(serialTable)
		if DebugFunction then print("Reconnect handler called Called") end
		Connected()
	end

	Samsung.Data = function(serialTable, data)
		ReportStatus("OK","")
		CommunicationTimer:Stop() 
		CommandProcessing = false
		local msg = DataBuffer .. Samsung:Read(1024)
		DataBuffer = "" 
		if DebugRx then PrintByteString(msg, "Received: ") end
		ParseResponse(msg)
		SendNextCommand()
	end

	Samsung.Closed = function(serialTable)
		if DebugFunction then print("Closed handler called Called") end
		Disconnected()
		ReportStatus("MISSING","Connection closed")
	end

	Samsung.Error = function(serialTable, error)
		if DebugFunction then print("Socket Error handler called Called") end
		Disconnected()
		ReportStatus("MISSING",error)
	end

	Samsung.Timeout = function(serialTable, error)
		if DebugFunction then print("Socket Timeout handler called Called") end
		Disconnected()
		ReportStatus("MISSING","Serial Timeout")
	end

	--Serial mode PowerOn handler uses the main api (see network power on below for more fun)
	Controls["PowerOn"].EventHandler = function()
		if DebugFunction then print("PowerOn Serial Handler Called") end
		PowerupTimer:Stop()
		--Documentation calls for 3 commands to be sent, every 2 seconds, for 3 repetitions
		Send( Request["PowerOn"], Controls["Broadcast"].Boolean, true )
		PowerupCount=0
		PowerupTimer:Start(2)
		PowerOnDebounce = true
		Timer.CallAfter( ClearDebounce, PowerOnDebounceTime)
	end
	
	Controls["PanelOn"].EventHandler = function()
		if DebugFunction then print("PanelOn Serial Handler Called") end
		Send( Request["PanelOn"], Controls["Broadcast"].Boolean)
	end

	Controls["Reset"].EventHandler = function()
		if DebugFunction then print("Reset handler called Called") end
		PowerupTimer:Stop()
		ClearVariables()
		Disconnected()
		Connect()
	end
	

--  Ethernet Command Function  --
else
	print("TCP Mode Initializing...")
	IPAddress = Controls.IPAddress
	Port = Controls.Port
	-- Create Sockets
	Samsung = TcpSocket.New()
	Samsung.ReconnectTimeout = 5
	Samsung.ReadTimeout = 10  --Tested to verify 6 seconds necessary for input switches;  Appears some TV behave mroe slowly
	Samsung.WriteTimeout = 10
	udp = UdpSocket.New()
	
	--Send the display the next command off the top of the queue
	function SendNextCommand()
		if DebugFunction then print("SendNextCommand() Called") end
		if CommandProcessing then
			-- Do Nothing
		elseif #CommandQueue > 0 then
			if not Samsung.IsConnected then
				Connect()
			else
				CommandProcessing = true
				if DebugTx then PrintByteString(CommandQueue[1], "Sending: ") end
				Samsung:Write( table.remove(CommandQueue,1) )
			end
		end
	end

	function Disconnected()
		if DebugFunction then print("Disconnected() Called") end
		if Samsung.IsConnected then
			Samsung:Disconnect()
		end
		CommandQueue = {}
		Heartbeat:Stop()
	end

	-- Clear old and open the socket
	function Connect()
		if DebugFunction then print("Connect() Called") end
		if IPAddress.String ~= "Enter an IP Address" and IPAddress.String ~= "" and Port.String ~= "" then
			if Samsung.IsConnected then
				Samsung:Disconnect()
			end
			Samsung:Connect(IPAddress.String, tonumber(Port.String))
		else
			ReportStatus("MISSING","No IP Address or Port")
		end
	end

	-- Handle events from the socket;  Nearly identical to Serial
	Samsung.EventHandler = function(sock, evt, err)
		if DebugFunction then print("Ethernet Socket Handler Called") end
		if evt == TcpSocket.Events.Connected then
			ReportStatus("OK","")
			Connected()
		elseif evt == TcpSocket.Events.Reconnect then
			--Disconnected()

		elseif evt == TcpSocket.Events.Data then
			ReportStatus("OK","")
			CommandProcessing = false
			TimeoutCount = 0
			local line = sock:Read(BufferLength)
			local msg = DataBuffer
			DataBuffer = "" 
			while (line ~= nil) do
				msg = msg..line
				line = sock:Read(BufferLength)
			end
			if DebugRx then PrintByteString(msg, "Received: ") end
			ParseResponse(msg)  
			SendNextCommand()
			
		elseif evt == TcpSocket.Events.Closed then
			Disconnected()
			ReportStatus("MISSING","Socket closed")

		elseif evt == TcpSocket.Events.Error then
			Disconnected()
			ReportStatus("MISSING","Socket error")

		elseif evt == TcpSocket.Events.Timeout then
			TimeoutCount = TimeoutCount + 1
			if TimeoutCount > 3 then
				Disconnected()
				ReportStatus("MISSING","Socket Timeout")
			end

		else
			Disconnected()
			ReportStatus("MISSING",err)

		end
	end

	--Ethernet specific event handlers
	Controls["IPAddress"].EventHandler = function()
		if DebugFunction then print("IP Address Event Handler Called") end
		if Controls["IPAddress"].String == "" then
			Controls["IPAddress"].String = "Enter an IP Address"
		end
		ClearVariables()
		Init()
	end
	Controls["Port"].EventHandler = function()
		if DebugFunction then print("Port Event Handler Called") end
		ClearVariables()
		Init()
	end

	-- Get the binary numerical value from a string IP address of the format "%d.%d.%d.%d"
	-- Consider hardening inputs for this function
	function IPV4ToValue(ipString)
		local bitShift = 24
		local ipValue = 0
		for octet in ipString:gmatch("%d+") do
			ipValue = ipValue + (tonumber(octet) << bitShift)
			bitShift = bitShift - 8
		end
		return ipValue or nil
	end

	-- Convert a 32bit number into an IPV4 string format
	function ValueToIPV4(value)
		return string.format("%d.%d.%d.%d", value >> 24, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
	end

	-- Compare IPAddresses as values (32bit integers)
	function IPMaskCheck(ip1, ip2, mask)
		return ip1 & mask == ip2 & mask
	end

	-- Accept IPAddresses as strings
	function IsIPInSubnet(ip1, ip2, mask)
		return IPMaskCheck(IPV4ToValue(ip1), IPV4ToValue(ip2), IPV4ToValue(mask))
	end

	-- PowerOn command on Ethernet requires a UDP broadcast wake-on-lan packet
	-- The packet needs the MAC of the display to be formed - GetDisplayInfo must be run once to get the MAC first.
	-- If Display is connected WiFi the poweron will not work
	Controls["PowerOn"].EventHandler = function()
		if DebugFunction then print("PowerOn Ethernet Handler Called") end
		--MAC from device is sent as string text, needs translation
		if Controls["MACAddress"].String:len()==12 then
			local mac = ""
			local macstr = Controls["MACAddress"].String
			local localIPAddress = nil
			local broadcastRange = "255.255.255.255"
			local deviceIpValue = IPV4ToValue(IPAddress.String)
			local nics = Network.Interfaces()

			--WOL Packet is 6 full scale bytes then 16 repetitions of Device MAC
			for i=1,6 do
				mac = mac..string.char( tonumber( "0x"..macstr:sub((i*2)-1, i*2) ) );  
			end
			local WOLPacket = "\xff\xff\xff\xff\xff\xff"
			for i=1,16 do
				WOLPacket = WOLPacket..mac
			end

			-- Check Gateways and generate a broadcast range if it is found to be 0.0.0.0.  This might be better as a property (if user wanted local range for some reason)
			for name,interface in pairs(nics) do
				if interface.Gateway == "0.0.0.0" then
					for _,nic in pairs(nics) do
						local ipValue = IPV4ToValue(nic.Address)
						local maskValue = IPV4ToValue(nic.Netmask or "255.255.255.0")  -- Mask may not be available in emulation mode
						if ipValue & maskValue == deviceIpValue & maskValue then
							localIPAddress = nic.Address
							if nic.BroadcastAddress then
								broadcastRange = nic.BroadcastAddress
							else
								broadcastRange = ValueToIPV4((deviceIpValue & maskValue) | (0xFFFFFFFF - maskValue))
							end
							break
						end
					end
					break
				end
			end

			--UDP broadcast of the wake on lan packet
			if DebugTx then print("Sending WoL packet UDP:", 9, broadcastRange) end
			udp:Open( localIPAddress )
			udp:Send( broadcastRange, 9, WOLPacket )
			udp:Close()
		end

		PowerupTimer:Stop()
		Send( Request["PowerOn"], Controls["Broadcast"].Boolean, true )
		--Also send the MDC command in case of broadcast awake signal
		PowerupCount = 0
		PowerupTimer:Start(2)
		PowerOnDebounce = true
		Timer.CallAfter( ClearDebounce, PowerOnDebounceTime)
	end
	
	Controls["PanelOn"].EventHandler = function()
		if DebugFunction then print("PanelOn Ethernet Handler Called") end
		Send( Request["PanelOn"], Controls["Broadcast"].Boolean )
	end

end


--  Device Request and Data handlers

--[[ Test the device once for
	0x10: Model Number
	0x67: Device Name
	0x8A: Model Name
	0x0B: Serial Number
	0x0E: SW Revision

	TODO: Find a way to test available inputs?
]]
-- Initial data grab from device
function GetDeviceInfo()
	if DebugFunction then print("GetDeviceInfo() Called") end
	if Properties["Get Device Info"].Value then
		if(Controls["SerialNumber"].String == "") then Send( Request["SerialNumber"] )  end
		if(Controls["DeviceFirmware"].String == "") then Send( Request["SWVersion"] )  end
		if(Controls["ModelNumber"].String == "") then Send( Request["ModelNumber"] )  end
		if(Controls["ModelName"].String == "") then Send( Request["ModelName"] )  end
		if(Controls["DeviceName"].String == "") then Send( Request["DeviceName"] )  end
		if(Controls["MACAddress"].String == "") then Send( Request["MACAddress"] )  end
	end
end


--[[  Response Data parser
	
	All response commands are hex bytes of the format
			Header   Command   DeviceID   DataLength   Ack/Nack   r-Command   Val 1.......   CheckSum
			0xAA     0xFF       0x??      0x??(int)  'A' or 'N'     0x??      0x??0x??...     0x??

	Command on a response is always 0xFF
	The Command it is in response to is r-Command
	Val 1 can be a sub command for extended commands

	Read until a header is found, then:
		1. Define a data object
		2. Parse the command, deviceID, length, and ack into the structure
		3. Parse the data bytes into an array
		4. Calculate the checksum

	Then check for:
		1. correct length
		2. Ack or Nack
		3. Checksum is valid
		4. Push the data object into a handler based on the command

	Recursively call if there is more data after the checksum. Stuff incomplete messages in the buffer
]]
function ParseResponse(msg)
	if DebugFunction then print("ParseResponse() Called") end

	--Message is too short, buffer the chunk and wait for more
	if msg:len()==0 then 
		--do nothing
	elseif msg:len() < 7 then
		DataBuffer = DataBuffer .. msg

	--Message doesn't start at begining.  Find the correct start then parse from there
	elseif msg:byte(1) ~= 170 or msg:byte(2) ~= 255 then
		local i=msg:find( (string.char(170)..string.char(255))  ) 
		if i ~= nil then
			ParseResponse( msg:sub(i,-1) )
		else
			DataBuffer = DataBuffer .. msg
		end
	
	--If the message length field is longer than the buffer, stuff back into the buffer and wait for a complete message
	elseif msg:len() < msg:byte(4)+5 then
		DataBuffer = DataBuffer .. msg

	--Handle a good message
	else
		local ResponseObj = {}
		--Pack the data for the handler
		ResponseObj['Command']=msg:byte(6)
		ResponseObj['DeviceId']=msg:byte(3)
		ResponseObj['DataLength']=msg:byte(4)
		ResponseObj['Data']={}
		ResponseObj['CheckSum']=msg:byte( 5+ResponseObj['DataLength'] )
		ResponseObj['CheckSumTotal']=msg:byte(2)+msg:byte(3)+msg:byte(4)+msg:byte(5)+msg:byte(6)
		--Read the data bytes into the data array (Ack/Nack and Cmd are part of the data length)
		if ResponseObj['DataLength']>2 then
			for i=7,(4+ResponseObj['DataLength']) do
				table.insert( ResponseObj['Data'], msg:byte(i) )
				ResponseObj['CheckSumTotal']=ResponseObj['CheckSumTotal']+msg:byte(i)
			end
		end
		-- Message char 5 is an 'A' for ACK;  Otherwise it's a failure response
		if msg:byte(5) ~= 65 then
			--NAK handler
			if DebugRx then print("NAK RESPONSE RECEIVED!") end
			ResponseObj['Ack']=false
		else
			ResponseObj['Ack']=true
		end

		--Checksum failures;  Don't handle
		if ResponseObj['CheckSum'] ~= ResponseObj['CheckSumTotal']%256 then
			if DebugRx then print( "Checksum failure: " .. ResponseObj['CheckSum'] .. ' does not match ' .. (ResponseObj['CheckSumTotal']%256) ) end
		else
			HandleResponse(ResponseObj)
		end

		--Re-process any remaining data
		ParseResponse( msg:sub(6+ResponseObj['DataLength'],-1) )
	end
end

-- Handler for good data from interface
function HandleResponse(msg)
	if DebugFunction then print("HandleResponse() Called") end
	
	--Serial Number
	if msg["Command"]==11 then
		if msg['Ack'] then
			Controls["SerialNumber"].String = ParseString(msg["Data"])
		else
			Controls["SerialNumber"].String = "Unavailable"
		end

	--SW Version
	elseif msg["Command"]==14 then
		if msg['Ack'] then
			Controls["DeviceFirmware"].String = ParseString(msg["Data"])
		else
			Controls["DeviceFirmware"].String = "Unavailable"
		end

	--Model Number
	elseif msg["Command"]==16 then
		if msg['Ack'] then
			Controls["PanelType"].String = PanelType[ msg["Data"][1] ] or ""
			Controls["ModelNumber"].String = ModelList[ msg["Data"][2] ] or ""
		else
			Controls["PanelType"].String = "Unavailable"
			Controls["ModelNumber"].String = "Unavailable"
		end

	--Input source Control response
	elseif msg["Command"]==20 then
		if DebugRx then print("Input Request change received: ",GetInputIndex(msg["Data"][1])) end
		--Don't need to do anything here as status resposne will show when input has changed.

	--System configuration
	elseif msg["Command"]==27 then
		--This command has sub commands
		--MAC Address
		if msg['Ack'] then
			if msg["Data"][1]==129 then
				local mac = ""
				for i=1,6 do
					mac = mac .. string.char(msg["Data"][i*2]) .. string.char(msg["Data"][1+i*2]) 
				end
				Controls["MACAddress"].String = mac
			else
				if DebugRx then PrintByteArray(msg["Data"], "Unrecognized System Configuration (0x1B) received: ") end
			end
		else
			Controls["MACAddress"].String = "Unavailable"
		end

	--Device Name
	elseif msg["Command"]==103 then
		if msg['Ack'] then
			Controls["DeviceName"].String = ParseString(msg["Data"])
		else 
			Controls["DeviceName"].String = "Unavailable"
		end
	
	--Model Name
	elseif msg["Command"]==138 then
		if msg['Ack'] then
			Controls["ModelName"].String = ParseString(msg["Data"])
			PluginInfo.Model = Controls["ModelName"].String
		else
			Controls["ModelName"].String = "Unavailable"
		end
	
	-- Catch NACK responses that aren't handled
	elseif not msg["Ack"] then
		print("Nack response received for command "..msg["Command"])

	--Handle Status command
	elseif msg["Command"]==0 then
		SetPowerLevel( msg["Data"][1] )
		Controls["Volume"].Value = msg["Data"][2]
		Controls["Mute"].Value = msg["Data"][3]
		SetActiveInput( GetInputIndex(msg["Data"][4]) )

	--Power Status
	elseif msg["Command"]==17 then
		SetPowerLevel( msg["Data"][1] )
	
	--Panel Status
	elseif msg["Command"]==249 then
		Controls["PanelStatus"].Boolean = (msg["Data"][1] == Request["PanelOn"].Data[1])

	--Mute Status
	elseif msg["Command"]==19 then
		Controls["Mute"].Value = msg["Data"][1]

	--Handle Anything else by printing the unexpected command (debug?)
	else
		if DebugRx then 
			print("Unexpected Data received.  Command: "..msg["Command"])
			PrintByteArray( msg["Data"] ) 
		end
	end
end

--[[    Input Handler functions      ]]

-- Re-Initiate communication when the user changes the IP address or Port or ID being queried
Controls["DisplayID"].EventHandler = function()
	if DebugFunction then print("Port Event Handler Called") end
	ClearVariables()
	Init()
end

--Controls Handlers
-- Power controls
Controls["PowerOff"].EventHandler = function()
	if DebugFunction then print("PowerOff Handler Called") end
	-- Stop the power on sequence if the user presses power off
	PowerupTimer:Stop()
	CommandQueue = {}
	Controls["PowerStatus"].Value = 0
	Send( Request["PowerOff"], Controls["Broadcast"].Boolean, true )
end
Controls["Reboot"].EventHandler = function()
	if DebugFunction then print("Reboot Handler Called") end
	Send( Request["Reboot"], Controls["Broadcast"].Boolean  )
end

-- Panel controls
Controls["PanelOff"].EventHandler = function()
	if DebugFunction then print("PanelOff Handler Called") end
	Controls["PanelStatus"].Boolean = false
	Send( Request["PanelOff"], Controls["Broadcast"].Boolean )
end

-- Input controls
for i=1,#Controls['InputButtons'] do
	Controls['InputButtons'][i].EventHandler = function(ctrl)
		if DebugFunction then print("Input Handler Called") end
		if ctrl.Boolean then
			Request["InputSet"]["Data"][1] = InputTypes[i].Value
			Send( Request["InputSet"], Controls["Broadcast"].Boolean  )
		end
	end
end
Controls['InputNext'].EventHandler = function()
	if DebugFunction then print("Input Handler Called") end
	i = GetInputIndex( Request["InputSet"]["Data"][1] )
	if InputTypes[i+1] ~= nil then
		Request["InputSet"]["Data"][1] = InputTypes[i+1].Value
	else
		Request["InputSet"]["Data"][1] = InputTypes[1].Value
	end
	Send( Request["InputSet"], Controls["Broadcast"].Boolean  )
end

-- Sound Controls
Controls["Mute"].EventHandler = function(ctrl)
	if DebugFunction then print("Mute Handler Called") end
	if ctrl.Value == 1 then
		Send( Request["MuteOn"], Controls["Broadcast"].Boolean  )
	else
		Send( Request["MuteOff"], Controls["Broadcast"].Boolean  )
	end
end
Controls["VolumeUp"].EventHandler = function()
	if DebugFunction then print("VolumeUp Handler Called") end
	Send( Request["VolumeUp"], Controls["Broadcast"].Boolean  )
end
Controls["VolumeDown"].EventHandler = function()
	if DebugFunction then print("VolumeDown Handler Called") end
	Send( Request["VolumeDown"], Controls["Broadcast"].Boolean  )
end
VolumeDebounce.EventHandler = function()
	if DebugFunction then print("VolumeDebounce Handler Called") end
	Request["VolumeSet"]["Data"][1] = math.floor(Controls["Volume"].Value)
	Send( Request["VolumeSet"], Controls["Broadcast"].Boolean  )
	VolumeDebounce:Stop()
end
Controls["Volume"].EventHandler = function(ctrl)
	if DebugFunction then print("Volume Handler Called") end
	VolumeDebounce:Start(.500)
end

-- Timer EventHandlers  --
Heartbeat.EventHandler = function()
	if DebugFunction then print("Heartbeat Event Handler Called") end
	Send( Request["PowerStatus"] )
	if Controls["PowerStatus"].Value==1 then
		Send( Request["Status"] )
		Send( Request["PanelStatus"] )
		GetDeviceInfo()
	end
end 


-- PowerOn command requires spamming the interface 3 times at 2 second intervals
PowerupTimer.EventHandler = function()
	if Controls["PowerStatus"].Value == 1 then
		PowerupTimer:Stop()
	else
		Send( Request["PowerOn"], Controls["Broadcast"].Boolean, true )
		PowerupCount= PowerupCount + 1
		if PowerupCount>2 then
			PowerupTimer:Stop()
		end
	end
end

-- Kick it off
SetupDebugPrint()
Init()



--[[ Additional Notes:
	Commands of interest but not used here
			0x01: Clock
			0x02: On time
			0x03: Off time
			0xA4 - 0xAE:  Timer controls
			0x09: Sound
			0x0D: Display Status
			0x4A: Standby state
			0xF9: Panel On/Off?  May be an integral part of multi-LCD panel dispays
			0x07: PiP Control
			0x04: Video Control for analog sources    (HSV etc)
			0x06: Video Control for digital sources   (RGB etc)
			0x16: Tuner control (analog TV)
			0x17: Tuner control (digital TV)
			0x61: Channel Up/Down
			0x85: Temperature
			0x1c: MagicInfo controls  (Samsung content feed)
			0xB4: Screen Mute
]]