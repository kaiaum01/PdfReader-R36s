local json = require("json")
local M = {serial=0, busy=false, ready=false}
local function read(path)
  local f=io.open(path,"rb")
  if not f then return nil end
  local s=f:read("*a"); f:close(); return s
end
function M.init(path)
  M.path=path; M.started=love.timer.getTime()
end
function M.send(request,callback)
  if M.busy then return false end
  if not M.ready then return false end
  M.serial=M.serial+1; request.id=M.serial
  os.remove(M.path.."/response.json")
  local f,e=io.open(M.path.."/request.tmp","wb")
  if not f then callback({ok=false,error=e});return false end
  f:write(json.encode(request));f:close()
  local ok,why=os.rename(M.path.."/request.tmp",M.path.."/request.json")
  if not ok then callback({ok=false,error=why});return false end
  M.busy={id=M.serial,callback=callback,started=love.timer.getTime()}
  return true
end
function M.update()
  if not M.ready then
    if read(M.path.."/ready.json") then M.ready=true
    elseif love.timer.getTime()-M.started>25 then M.error="O motor PDF não iniciou. Veja log.txt na pasta do app." end
    return
  end
  if not M.busy then return end
  local s=read(M.path.."/response.json")
  if s then
    local ok,r=pcall(json.decode,s)
    if ok and r.id==M.busy.id then
      os.remove(M.path.."/response.json")
      local cb=M.busy.callback;M.busy=false;cb(r);return
    end
  end
  if love.timer.getTime()-M.busy.started>90 then
    M.error="O PDF demorou mais de 90 segundos. Saia e tente um arquivo menor."
  end
end
return M
