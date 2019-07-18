setTickRate(30)
sxSetConfig(1,0,1)
sxCfgLinearGraph(0,0,0,8400)

sxSetLinearThresh(0,0,1000,0,255,0,0)  --green at 4000 RPM
sxSetLinearThresh(1,0,6000,0,0,255,0)  --blue at 6000 RPM
sxSetLinearThresh(2,0,7800,255,0,0,10) --red+flash at 7800 RPM

--configure first alert (right LED) as coolant temperature (F)
sxSetAlertThresh(0,0,205,225,255,0,0) --yellow warning at 205F
sxSetAlertThresh(0,1,225,255,0,0,10) -- red flash at 225F

--configure first alert (right LED) as oil temperature (F)
sxSetAlertThresh(1,0,245, 255,255,0,0) --yellow warning at 245F
sxSetAlertThresh(1,1,260, 255,0,0,10) -- red flash at 260F

flWheelId = addChannel("FLWheelSpd", 10, 0, 0, 200, "MPH")
frWheelId = addChannel("FRWheelSpd", 10, 0, 0, 200, "MPH")
rlWheelId = addChannel("RLWheelSpd", 10, 0, 0, 200, "MPH")
rrWheelId = addChannel("RRWheelSpd", 10, 0, 0, 200, "MPH")

function processWheel(id, dataLow, dataHigh)
  --wheel speed is 13 bits long, little endian
  --low byte high byte
  --76543210 76543210
  --11111111 11111XXX
  if dataLow == nil or dataHigh == nil then
    return
  end
  local highByte = bit.band(dataHigh, 0x1F)
  local lowByte = dataLow
  local value = highByte * 256 + lowByte
  -- convert to kph then to mph
  value = value * 0.0625 * 0.621371 
  setChannel(id, value)
  --println("whl spd" ..value)
end

--create gear channel
gearId = addChannel("Gear", 10, 0, 0, 6)

function onTick()
  processWheel(flWheelId, getChannel("MK20F0"), getChannel("MK20F1"))
  processWheel(frWheelId, getChannel("MK20F2"), getChannel("MK20F3"))
  processWheel(rlWheelId, getChannel("MK20F4"), getChannel("MK20F5"))
  processWheel(rrWheelId, getChannel("MK20F6"), getChannel("MK20F7"))

  sxUpdateLinearGraph(getChannel("RPM"))

  --update engine temp alert
  sxUpdateAlert(0, getChannel("Coolant"))

  --update oil pressure alert
  sxUpdateAlert(1, getChannel("OilTemp"))
  plus = getChannel("CruisePlus") 
  if plus == 1.0 then
    txButton(1, 1)
  end
  minus = getChannel("CruiseMinus")
  if minus == 1.0 then
    txButton(0, 1) 
  end

  -- calculate gear: tire diameter(cm), final gear ratio, individual gear ratios 1-6
  local gear = calcGear(65.262, 3.62, 4.23, 2.53, 1.67, 1.23, 1.0, 0.83)
  if gear == nil then
     gear = 0
  end
  setChannel(gearId, gear)
  sxSetDisplay(0, gear)
end
