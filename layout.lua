local CurrentPage = pagenames[props["page_index"].Value]
local colors = {  
  Background  = {232,232,232},
  Transparent = {255,255,255,0},
  Text        = {24,24,24},
  Header      = {0,0,0},
  Button      = {48,32,40},
  Red         = {217,32,32},
  DarkRed     = {80,16,16},
  Green       = {32,217,32},
  OKGreen     = {48,144,48},
  Blue        = {32,32,233},
  Black       = {0,0,0},
  White       = {255,255,255},
  Gray        = {96,96,96}
}

if CurrentPage == "Setup" then
  -- User defines connection properties
  table.insert(graphics,{Type="GroupBox",Text="Connect",Fill=colors.Background,StrokeWidth=1,CornerRadius=4,HTextAlign="Left",Position={5,5},Size={400,120}})
  if props["Connection Type"].Value=="Ethernet" then 
    table.insert(graphics,{Type="Text",Text="IP Address",Position={15,35},Size={100,16},FontSize=14,HTextAlign="Right"})
    layout["IPAddress"] = {PrettyName="Settings~IP Address",Style="Text",Color=colors.White,Position={120,35},Size={99,16},FontSize=12}
    table.insert(graphics,{Type="Text",Text="Port",Position={15,60},Size={100,16},FontSize=14,HTextAlign="Right"})
    layout["Port"] = {PrettyName="Settings~Port",Style="Text",Color=colors.White,Position={120,60},Size={99,16},FontSize=12}
    table.insert(graphics,{Type="Text",Text="(1515 default)",Position={221,60},Size={100,18},FontSize=10,HTextAlign="Left"})
    table.insert(graphics,{Type="Text",Text="Reboot",Position={315,35},Size={70,14},FontSize=12,HTextAlign="Center",Color=colors.Text})
    layout["Reboot"] = {PrettyName="Power~Reboot", Style="Button", Color=colors.Button, FontColor=colors.Red, FontSize=14, CornerRadius=2, Position={325,48}, Size={50,20} }
  else
    table.insert(graphics,{Type="Text",Text="Reset Serial",Position={5,32},Size={110,16},FontSize=14,HTextAlign="Right"})
    layout["Reset"] = {PrettyName="Settings~Reset Serial", Style="Button", Color=colors.Button, FontColor=colors.Red, FontSize=14, CornerRadius=2, Position={120,30}, Size={50,20} }
    table.insert(graphics,{Type="Text",Text="Reboot",Position={15,57},Size={100,16},FontSize=14,HTextAlign="Right"})
    layout["Reboot"] = {PrettyName="Power~Reboot", Style="Button", Color=colors.Button, FontColor=colors.Red, FontSize=14, CornerRadius=2, Position={120,55}, Size={50,20} }
  end
  table.insert(graphics,{Type="Text",Text="Display ID",Position={15,85},Size={100,16},FontSize=14,HTextAlign="Right"})
  layout["DisplayID"] = {Type="Text",PrettyName="Settings~Display ID Number", Style="Text", FontColor=colors.Text, Position={120,85}, Size={99,16}, FontSize=12}
  

  -- Status fields updated upon connect show model/name/serial/sw rev
  table.insert(graphics,{Type="GroupBox",Text="Status",Fill=colors.Background,StrokeWidth=1,CornerRadius=4,HTextAlign="Left",Position={5,135},Size={400,220}})
  layout["Status"] = {PrettyName="Status~Connection Status", Position={40,165}, Size={330,32}, Padding=4 }
  table.insert(graphics,{Type="Text",Text="Device Name",Position={15,212},Size={100,16},FontSize=12,HTextAlign="Right"})
  layout["DeviceName"] = {PrettyName="Status~Device Name", Style="Text", HTextAlign="Left", IsReadOnly=true, Color=colors.Transparent, StrokeWidth=0, FontSize=14, IsBold=true, FontColor=colors.Text, Position={120,211}, Size={255,16} }
  table.insert(graphics,{Type="Text",Text="Model Name",Position={15,235},Size={100,16},FontSize=12,HTextAlign="Right"})
  layout["ModelName"] = {PrettyName="Status~Model Name", Style="Text", HTextAlign="Left", IsReadOnly=true, Color=colors.Transparent, StrokeWidth=0, FontSize=14, IsBold=true, FontColor=colors.Text, Position={120,234}, Size={255,16} }
  table.insert(graphics,{Type="Text",Text="Serial Number",Position={15,258},Size={100,16},FontSize=12,HTextAlign="Right"})
  layout["SerialNumber"] = {PrettyName="Status~Serial Number", Style="Text", HTextAlign="Left", IsReadOnly=true, Color=colors.Transparent, StrokeWidth=0, FontSize=14, IsBold=true, FontColor=colors.Text, Position={120,257}, Size={255,16} }
  table.insert(graphics,{Type="Text",Text="Software Version",Position={15,281},Size={100,16},FontSize=12,HTextAlign="Right"})
  layout["DeviceFirmware"] = {PrettyName="Status~SW Version", Style="Text", HTextAlign="Left", IsReadOnly=true, Color=colors.Transparent, StrokeWidth=0, FontSize=14, IsBold=true, FontColor=colors.Text, Position={120,280}, Size={255,16} }
  table.insert(graphics,{Type="Text",Text="MAC Address",Position={15,304},Size={100,16},FontSize=12,HTextAlign="Right"})
  layout["MACAddress"] = {PrettyName="Status~MAC Address", Style="Text", HTextAlign="Left", IsReadOnly=true, Color=colors.Transparent, StrokeWidth=0, FontSize=14, IsBold=true, FontColor=colors.Text, Position={120,303}, Size={255,16} }

  table.insert(graphics,{Type="Text",Text="Samsung Commercial Display Plugin version "..PluginInfo.Version,Position={15,340},Size={380,14},FontSize=10,HTextAlign="Right", Color=colors.Gray})

  --Invisible Controls for pin access to data
  layout["ModelNumber"] = {PrettyName="Status~Model Family", Style="Text", HTextAlign="Left", IsReadOnly=true, Color=colors.Transparent, StrokeWidth=0, FontSize=14, IsBold=true, FontColor=colors.Text, Position={1,1}, Size={1,1}, IsInvisible=true }
  layout["PanelType"] = {PrettyName="Status~Panel Type", Style="Text", HTextAlign="Left", IsReadOnly=true, Color=colors.Transparent, StrokeWidth=0, FontSize=14, IsBold=true, FontColor=colors.Text, Position={1,1}, Size={1,1}, IsInvisible=true }

elseif CurrentPage == "Control" then
  -- Control interface for the monitor
  table.insert(graphics,{Type="GroupBox",Text="Control",Fill=colors.Background,StrokeWidth=1,CornerRadius=4,HTextAlign="Left",Position={5,5},Size={305,665}})
  table.insert(graphics,{Type="Text",Text="Broadcast Mode",Position={108,20},Size={125,25},FontSize=12,HTextAlign="Right", VTextAlign="Middle", Color=colors.Text})
  layout["Broadcast"] = {PrettyName="Settings~Broadcast", Style="Button", UnlinkOffColor=true, Color=colors.Blue, OffColor=colors.Gray, FontSize=14, CornerRadius=2, Position={234,20}, Size={65,25} }
  -- Power
  table.insert(graphics,{Type="Header",Text="Power",Position={15,55},Size={285,14},FontSize=12,HTextAlign="Center",Color=colors.Header})
  table.insert(graphics,{Type="Text",Text="On",Position={12,70},Size={71,14},FontSize=12,HTextAlign="Center",Color=colors.Text})
  layout["PowerOn"] = {PrettyName="Power~On", Style="Button", Color=colors.Button, FontColor=colors.Hreen, FontSize=14, CornerRadius=2, Position={15,83}, Size={65,25} }
  table.insert(graphics,{Type="Text",Text="Off",Position={231,70},Size={71,14},FontSize=12,HTextAlign="Center",Color=colors.Text})
  layout["PowerOff"] = {PrettyName="Power~Off", Style="Button", Color=colors.Button, FontColor=colors.Red, FontSize=14, CornerRadius=2, Position={234,83}, Size={65,25} }
  --table.insert(graphics,{Type="Text",Text="Status",Position={12,70},Size={71,14},FontSize=12,HTextAlign="Center",Color=colors.Text})
  layout["PowerStatus"] = {PrettyName="Power~Status", Style="LED", Color=colors.Blue, OffColor=colors.DarkRed, UnlinkOffColor=true, CornerRadius=6, Position={147,85}, Size={20,20} }
  --Panel
  table.insert(graphics,{Type="Header",Text="Panel",Position={15,120},Size={285,14},FontSize=12,HTextAlign="Center",Color=colors.Header})
  table.insert(graphics,{Type="Text",Text="On",Position={12,135},Size={71,14},FontSize=12,HTextAlign="Center",Color=colors.Text})
  layout["PanelOn"] = {PrettyName="Panel~On", Style="Button", Color=colors.Button, FontColor=colors.Hreen, FontSize=14, CornerRadius=2, Position={15,148}, Size={65,25} }
  table.insert(graphics,{Type="Text",Text="Off",Position={231,135},Size={71,14},FontSize=12,HTextAlign="Center",Color=colors.Text})
  layout["PanelOff"] = {PrettyName="Panel~Off", Style="Button", Color=colors.Button, FontColor=colors.Red, FontSize=14, CornerRadius=2, Position={234,148}, Size={65,25} }
  --table.insert(graphics,{Type="Text",Text="Status",Position={12,135},Size={71,14},FontSize=12,HTextAlign="Center",Color=colors.Text})
  layout["PanelStatus"] = {PrettyName="Panel~Status", Style="LED", Color=colors.Blue, OffColor=colors.DarkRed, UnlinkOffColor=true, CornerRadius=6, Position={147,150}, Size={20,20} }
  -- Inputs
  table.insert(graphics,{Type="Header",Text="Input",Position={15,185},Size={285,14},FontSize=12,HTextAlign="Center",Color=colors.Header})
  table.insert(graphics,{Type="Text",Text="Current Input",Position={12,204},Size={75,20},FontSize=12,HTextAlign="Right", VTextAlign="Middle", Color=colors.Text})
  layout["Input"] = {PrettyName="Input~Current Input", Style="Text", FontColor=colors.Black, FontSize=14, Position={88,204} , Size={211,20} }
  local i,j=0,0
  for val,input in pairs(InputTypes) do
    if (i+(j*4)) < InputCount then
      table.insert(graphics,{Type="Text",Text=input.Name,Position={12+(73*i),225+j*45},Size={71,22},FontSize=10,Color=colors.Text,HTextAlign="Center", VTextAlign="Bottom"})
      layout["InputButtons "..(j*4+1+i)] = {PrettyName="Input~"..input.Name, Style="Button", UnlinkOffColor=true, Color=colors.Blue, OffColor=colors.Button, FontColor=colors.White, FontSize=14, Position={15+(73*i), 245+j*45}, Size={65,25} }
      layout["InputStatus "..(j*4+1+i)] = {PrettyName="Input~Status "..input.Name, Style="LED", Color=colors.White, OffColor=colors.Transparent, UnlinkOffColor=true, StrokeWidth=0, Position={68+(73*i), 247+j*45}, Size={10,10}, ZOrder=-1000}
      i=i+1
      if(i>3)then 
        j=j+1
        i=0
      end
    end
  end
  --[[ Next Source Functionality removed due to instability with different models not having all inputs available
  table.insert(graphics,{Type="Text",Text="Next Source",Position={12+(73*i),160+j*45},Size={71,22},FontSize=10,Color=colors.Text,HTextAlign="Center", VTextAlign="Bottom"})
  layout["InputNext"] = { PrettyName="Input~Next Source", Style="Button", Color=colors.Button, FontColor=colors.Black, FontSize=14, Position={15+(73*i),180+j*45}, Size={65,25} }
  ]]

  table.insert(graphics,{Type="Header",Text="Volume",Position={15,555},Size={285,14},FontSize=12,HTextAlign="Center",Color=colors.Header})
  layout["VolumeDown"] = { PrettyName="Volume~Down", Style="Button", Color=colors.Button, IconColor=colors.White, Position={15,577}, Size={30,30} }
  layout["Volume"] = { PrettyName="Volume~Level", Style="Fader", Color=colors.Button, Position={50,575}, Size={140,35} }
  layout["VolumeUp"] = { PrettyName="Volume~Up", Style="Button", Color=colors.Button, IconColor=colors.White, Position={195,577}, Size={30,30} }
  table.insert(graphics,{Type="Text",Text="Mute",Position={224,566},Size={85,15},FontSize=10,Color=colors.Text,HTextAlign="Center", VTextAlign="Bottom"})
  layout["Mute"] = { PrettyName="Volume~Mute", Style="Button", Color=colors.Red, Position={234,580}, Size={65,25} }

  table.insert(graphics,{Type="Text",Text="Samsung Commercial Display Plugin version "..PluginInfo.Version,Position={15,655},Size={285,14},FontSize=10,HTextAlign="Right", Color=colors.Gray})
end