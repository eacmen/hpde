-- Log messages from CAN bus
-- be sure to set the correct baud rate in the CAN settings

-- ID of CAN message to capture and display

CAN_ID = 496 
--------------------------------------------------
-- change this to 0 for CAN bus 1, or 1 for CAN bus 2
canBus = 0
--------------------------------------------------

--this function drains all pending CAN messages
--and outputs messages to the log
function outputCAN()
   repeat 
      id, ext, data = rxCAN(canBus, 1000)
      if id ~= nil and id == CAN_ID then
         print('[' ..id ..']: ')
         for i = 1,#data do
            -- y u no have %x rcp?!?
            print(string.format("%d, ", data[i]))
            --print(data[i] ..', ')
         end
         println('')
      end
   until id == nil
   println('Timeout: no CAN data')
end
 
function onTick()
   outputCAN()
end

setTickRate(60)
