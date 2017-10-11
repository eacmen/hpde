-- This code is derived from the Auto Sport Labs Race Capture Pro wiki and forums
-- modifications were made to support multiple Hero4 Session Cameras

script_start_time = getUptime( )

STATUS_PREINIT   = 0
STATUS_INIT_SENT = 1
STATUS_GOT_IP    = 2
STATUS_READY     = 3
STATUS_RECORDING = 4
STATUS_FAIL      = 5
STATUS_STOPPED   = 6

TRIGGER_INIT       = 0
TRIGGER_STARTING   = 1
TRIGGER_STOPPING   = 2
TRIGGER_STARTED    = 3

-- Time to wait after trying to join camera wifi to give up (20 seconds)
INIT_TIMEOUT = 20000

-- Serial Port WiFi is connected to
WIFI_SERIAL_PORT = 4

-- List your cameras here
cameras = {
   { ssid='GoPro1',
     psk='password1',
     mac="001122334455",
     status=STATUS_PREINIT,
     init_time=0
   },
   { ssid='GoPro2',
     psk='password2',
     mac="001122334456",
     status=STATUS_PREINIT,
     init_time=0
   }
}

-- Number of cameras in above table
camera_count = 2

-- Set to 1 if testing GoPros in the garage
bench_test =  0

--Speed threshold to start recording
START_SPEED = 20

--Speed threshold to stop recording
STOP_SPEED = 5

--How fast we check, in Hz
tickRate = 10

--Set this to 1 to log communications between RCP & WiFi
debug = 0

gopro_id = addChannel("GoPro", 10, 0, 0, 100, "")

gopro_num_recording = 0

trigger_state = TRIGGER_INIT

active_cam = 1


-----------------------------
--DO NOT EDIT BELOW
-----------------------------

function log(msg)
--   println('[GoProWiFi ' ..tostring(active_cam) ..'] '  ..msg)
end

function send_crlf()
  writeCSer(WIFI_SERIAL_PORT, 13)
  writeCSer(WIFI_SERIAL_PORT, 10)
end

function send_raw(val)
  for i=1, #val do
    local c = string.sub(val, i, i)
    writeCSer(WIFI_SERIAL_PORT, string.byte(c))
  end
end

function send_AT(val)
  if debug == 1 then log('send: ' ..val) end
  send_raw(val)
  send_crlf()
end

function toInt(val)
  return string.sub(val, 1, -3)
end

function http_GET(url)
  send_AT('AT+CIPSTART="TCP","10.5.5.9",80')
  sleep(500)
  local crlf = string.char(13) ..string.char(10)
  local get = 'GET ' ..url ..' HTTP/1.0' ..crlf ..crlf
  send_AT('AT+CIPSEND=' ..toInt(#get))
  sleep(100)
  send_raw(get)
  sleep(100)
  send_AT("AT+CIPCLOSE") 
end

function send_shutter(cam, cmd)
  http_GET('/bacpac/SH?t=' ..cam.psk ..'&p=%' ..cmd)
end

function start_gopro(cam)
--  log('start GoPro')
  send_shutter(cam, '01')
end

function stop_gopro(cam)
--   log('stopping GoPro')
   send_shutter(cam, '00')
end

-- Sesssion Models require WoL packet, should have no effect
-- on non-Session models
function wake_gopro(cam) 
  local macChars = '' 
  for w in string.gmatch(cam.mac, "[0-9A-Za-z][0-9A-Za-z]") do 
     macChars = macChars .. string.char(tonumber(w, 16)) 
  end
    
  local magicPacket = string.char(0xff):rep(6) .. macChars:rep(16);
  send_AT('AT+CIPSTART="UDP","10.5.5.9",9') 
  sleep(500) 
  send_AT('AT+CIPSEND=' ..toInt(#magicPacket)) 
  sleep(100) 
  send_raw(magicPacket) 
  sleep(100) 
  send_AT("AT+CIPCLOSE") 
  sleep(2000) 
end

function init_wifi(cam)
--  log('initializing')
  send_AT('AT+RST')
  sleep(2000)
  send_AT('AT+CWMODE_CUR=1')
  sleep(1000)
  send_AT('AT+CWJAP_CUR="' ..cam.ssid ..'","' ..cam.psk ..'"')
end

function process_incoming(cam)
   local line = readSer(WIFI_SERIAL_PORT, 100)
   
   if line ~= '' and debug == 1 then print(line) end
  
   if string.match(line, 'WIFI GOT IP') then 
      cam.status = STATUS_GOT_IP
   end
  
   if cam.status == STATUS_GOT_IP and string.match(line, 'OK') then
      cam.status = STATUS_READY
--      log('ready for GoPro')
   end
end

function set_trigger_state( )

   if trigger_state == TRIGGER_STARTING and gopro_num_recording == camera_count then
      trigger_state = TRIGGER_STARTED
   end

   if bench_test == 1 then
      if (getUptime( ) - script_start_time) < 5000 then
         trigger_state = TRIGGER_STARTING
      end

      if (getUptime( ) - script_start_time) > 90000 then
         trigger_state = TRIGGER_STOPPING
      end
      return
   else
      local speed = getGpsSpeed( )

      if speed > START_SPEED and trigger_state ~= TRIGGER_STARTED then
         trigger_state = TRIGGER_STARTING
      end

      if speed < STOP_SPEED and trigger_state ~= TRIGGER_INIT then
         trigger_state = TRIGGER_STOPPING
      end
   end
end

function check_gopro()

   set_trigger_state( )

   if trigger_state == TRIGGER_STARTED then
      return
   end

   if (cameras[active_cam].status == STATUS_RECORDING or cameras[active_cam].status == STATUS_FAIL or cameras[active_cam].status == STATUS_STOPPED) then

      if trigger_state == TRIGGER_STOPPING and cameras[active_cam].status == STATUS_RECORDING then
         cameras[active_cam].status = STATUS_READY
         return
      end
      
      -- we need to move to the next camera
      if cameras[active_cam].status == STATUS_FAIL or cameras[active_cam].status == STATUS_STOPPED then
         -- lets try this camera again if we can
         cameras[active_cam].status = STATUS_PREINIT
      end

      active_cam = active_cam + 1
      if active_cam == (camera_count+1) then
         active_cam = 1
      end
   end

   if cameras[active_cam].status == STATUS_PREINIT then
      init_wifi(cameras[active_cam])
      cameras[active_cam].status    = STATUS_INIT_SENT
      cameras[active_cam].init_time = getUptime( )
      return
   end

   process_incoming(cameras[active_cam]) -- sets GOT_IP or READY state on camera
      
   if cameras[active_cam].status == STATUS_INIT_SENT and getUptime() > cameras[active_cam].init_time + INIT_TIMEOUT then
      println('could not connect to GoPro ' ..tostring(active_cam))
      cameras[active_cam].status = STATUS_FAIL
      return
   end
  
  if cameras[active_cam].status ~= STATUS_READY then
    return
  end
  
  if trigger_state == TRIGGER_STARTING then
     wake_gopro(cameras[active_cam])
     start_gopro(cameras[active_cam])
     cameras[active_cam].status = STATUS_RECORDING
     gopro_num_recording = (gopro_num_recording + 1)
     return
  end

  if trigger_state == TRIGGER_STOPPING then
     stop_gopro(cameras[active_cam])
     cameras[active_cam].status = STATUS_STOPPED
     gopro_num_recording = (gopro_num_recording - 1)
     return
  end
end

function onTick()
   check_gopro()
   
   setChannel(gopro_id, gopro_num_recording)
end

setTickRate(tickRate)
