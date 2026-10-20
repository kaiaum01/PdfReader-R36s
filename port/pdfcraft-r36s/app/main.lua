local json=require("json")
local U=require("ui")
local R=require("reader")
local B=require("backend")
local I=require("i18n")
local T=I.t
local S={view="boot",entries={},selected=1,offset=0,history={},night=false,menuIndex=1,browserTab=1,readerHUD=true,toolIndex=1,favorites={},languageIndex=1}
local docs=os.getenv("PDFCRAFT_DOCUMENTS") or "documents"
local session=os.getenv("PDFCRAFT_SESSION") or "/tmp/pdfcraft-r36s"
local state={progress={},recent={}}
local repeatKey,repeatAt,repeatElapsed
local bootDone=false
local function save()
  if S.doc then state.progress[S.doc.path]={page=S.doc.page} end
  state.night=S.night;state.swap=nil;state.controlsVersion=2;state.directory=S.directory;state.favorites=S.favorites;state.recent=S.recent
  local ok,written=pcall(love.filesystem.write,"state.json",json.encode(state))
  return ok and written==true
end
local function toast(s) S.toast=s;S.toastUntil=love.timer.getTime()+3 end
local function errorMessage(s,returnView)
  S.error=I.error(s or T("Falha desconhecida."));S.errorReturn=returnView or "browser";S.view="error"
end
local function request(v,cb)
  return B.send(v,function(r)
    if r.ok then cb(r) else errorMessage(r.error,S.doc and "reader" or "browser") end
  end)
end
local function list(path,selectPath)
  if B.busy then return end
  request({op="list",path=path},function(r)
    S.directory=r.path;S.parent=r.parent;S.allEntries=r.entries;S.entries=r.entries;S.selected=1;S.offset=0
    if selectPath then for i,e in ipairs(S.entries) do if e.path==selectPath then S.selected=i end end end
    S.offset=math.max(0,S.selected-6);S.browserTab=1;S.view="browser";save()
    if r.truncated then toast(T("Mostrando os primeiros 4.000 itens.")) end
  end)
end
local function renderRegion()
  if not S.doc or B.busy then return end
  local region=R.region();region.op="render";region.page=S.doc.page
  request(region,function(r)
    local ok,e=pcall(R.loadImage,r.file,r)
    if not ok then errorMessage(e,"reader");return end
    S.renderMillis=r.millis;save()
    if (r.warnings or 0)>0 then toast(T("A página contém elementos que não foram exibidos.")) end
  end)
end
local function render(keepCenter)
  if not S.doc or B.busy then return end
  local d=S.doc
  if R.textMode then
    request({op="text",page=d.page},function(r) R.wrap(r.text);R.textY=0;save() end)
  else
    R.prepare(d.pages[d.page+1],keepCenter);renderRegion()
  end
end
local function openDocument(path,password)
  if B.busy then return end
  R.clear();S.doc=nil
  B.send({op="open",path=path,password=password},function(r)
    if not r.ok then
      if r.code=="password" then
        S.passwordPath=path;S.password="";S.keyIndex=1;S.upper=false;S.view="password";S.passwordHint=I.error(r.error)
      else errorMessage(r.error,"browser") end
      return
    end
    local record=state.progress[path]
    local page=record and tonumber(record.page) or 0
    page=math.max(0,math.min(r.count-1,page or 0))
    S.recent=S.recent or {};for i=#S.recent,1,-1 do if S.recent[i]==path then table.remove(S.recent,i) end end;table.insert(S.recent,1,path);while #S.recent>30 do table.remove(S.recent) end
    S.doc={path=path,name=path:match("([^/]+)$") or path,pages=r.pages,count=r.count,page=page}
    R.zoom=1;R.fit="width";R.textMode=false;S.view="reader";S.readerHUD=true;R.y=57;R.h=373;render(false)
  end)
end
local function turnPage(step)
  if not S.doc or B.busy then return end
  local n=math.max(0,math.min(S.doc.count-1,S.doc.page+step))
  if n~=S.doc.page then S.doc.page=n;R.clear();render(false) end
end
local function zoom(step)
  if not S.doc or B.busy then return end
  if R.textMode then R.textSize=math.max(16,math.min(40,R.textSize+step*2));R.wrap();return end
  R.zoom=math.max(.5,math.min(32,R.zoom*(step>0 and 1.25 or .8)));render(true)
end
local function closeDocument()
  save();R.clear();S.doc=nil
  request({op="close"},function() list(S.directory or docs) end)
end
local function menuItems()
  if S.doc then return {T("Continuar leitura"),T("Ir para página"),T("Alternar modo de leitura"),T("Alternar modo noturno"),"Idioma / Language",T("Voltar para arquivos"),T("Sair")} end
  return {T("Voltar para arquivos"),T("Pasta de documentos"),T("Cartão: /roms"),T("Segundo cartão: /roms2"),"Idioma / Language",T("Sair")}
end
local function chooseLanguage(first)
  S.firstWelcome=first;S.languageIndex=state.language=="en" and 2 or 1
  S.languageError=nil;S.view="language"
end
local function activateMenu()
  local n=S.menuIndex
  if S.doc then
    if n==1 then S.view="reader"
    elseif n==2 then S.jump=S.doc.page+1;S.view="jump"
    elseif n==3 then S.view="reader";R.textMode=not R.textMode;render(false)
    elseif n==4 then S.night=not S.night;save();S.view="reader"
    elseif n==5 then chooseLanguage(false)
    elseif n==6 then closeDocument()
    elseif n==7 then love.event.quit() end
  else
    if n==1 then S.view="browser"
    elseif n==2 then list(docs)
    elseif n==3 then list("/roms")
    elseif n==4 then list("/roms2")
    elseif n==5 then chooseLanguage(false)
    elseif n==6 then love.event.quit() end
  end
end
local characters="abcdefghijklmnopqrstuvwxyz0123456789 .-_@!#$%&*()+/=:;,?[]{}"
local function applyBrowserTab()
  S.entries={}
  if S.browserTab==1 then for _,e in ipairs(S.allEntries or {}) do S.entries[#S.entries+1]=e end
  elseif S.browserTab==2 then for _,path in ipairs(S.recent or {}) do for _,e in ipairs(S.allEntries or {}) do if e.path==path then S.entries[#S.entries+1]=e end end end
  else for _,e in ipairs(S.allEntries or {}) do if S.favorites[e.path] then S.entries[#S.entries+1]=e end end end
  S.selected=1;S.offset=0
end
local function action(a)
  if a=="quit" then save();love.event.quit();return end
  if S.view=="language" then
    if a=="up" or a=="down" or a=="left" or a=="right" then
      S.languageIndex=3-S.languageIndex
    elseif a=="back" and not S.firstWelcome then S.view="menu"
    elseif a=="confirm" then
      local previous=state.language
      state.language=S.languageIndex==1 and "pt" or "en"
      if save() then
        I.set(state.language);S.view=S.firstWelcome and "boot" or "menu";S.firstWelcome=false
      else
        state.language=previous
        S.languageError="Não foi possível salvar. / Could not save."
      end
    end
    return
  end
  if B.error then return end
  if B.busy then return end
  if S.view=="error" then
    if a=="back" or a=="confirm" then
      S.view=S.errorReturn
      if S.view=="browser" and not S.directory then list(docs) end
    end
  elseif S.view=="browser" then
    if a=="down" then S.selected=math.min(#S.entries,S.selected+1)
    elseif a=="up" then S.selected=math.max(1,S.selected-1)
    elseif a=="right" then S.browserTab=S.browserTab%3+1;applyBrowserTab()
    elseif a=="left" then S.browserTab=(S.browserTab+1)%3+1;applyBrowserTab()
    elseif a=="favorite" then local e=S.entries[S.selected];if e and not e.dir then S.favorites[e.path]=not S.favorites[e.path];save();if S.browserTab==3 then applyBrowserTab() end end
    elseif a=="confirm" then
      local e=S.entries[S.selected]
      if e then if e.dir then list(e.path) else openDocument(e.path) end end
    elseif a=="back" and S.parent then list(S.parent,S.directory)
    elseif a=="menu" then S.menuIndex=1;S.view="menu" end
    if S.selected>S.offset+6 then S.offset=S.selected-6 end
    if S.selected<=S.offset then S.offset=math.max(0,S.selected-1) end
  elseif S.view=="reader" then
    if a=="back" then closeDocument()
    elseif a=="prev" then turnPage(-1)
    elseif a=="next" then turnPage(1)
    elseif a=="zoom_in" then zoom(1)
    elseif a=="zoom_out" then zoom(-1)
    elseif a=="confirm" then S.readerHUD=not S.readerHUD;R.y=S.readerHUD and 57 or 0;R.h=S.readerHUD and 373 or 480;R.clamp();if not R.textMode then render(true) end
    elseif a=="text" then R.textMode=not R.textMode;render(false)
    elseif a=="night" then S.night=not S.night;save()
    elseif a=="menu" then S.toolIndex=1;S.view="tools"
    elseif a=="up" then if R.textMode then R.textY=R.textY-65 else R.panY=R.panY-65 end
    elseif a=="down" then if R.textMode then R.textY=R.textY+65 else R.panY=R.panY+65 end
    elseif a=="left" then R.panX=R.panX-65
    elseif a=="right" then R.panX=R.panX+65 end
    R.clamp()
  elseif S.view=="tools" then
    if a=="up" then S.toolIndex=math.max(1,S.toolIndex-1)
    elseif a=="down" then S.toolIndex=math.min(7,S.toolIndex+1)
    elseif a=="back" or a=="menu" then S.view="reader"
    elseif a=="prev" then S.toolIndex=math.max(1,S.toolIndex-1)
    elseif a=="next" then S.toolIndex=math.min(7,S.toolIndex+1)
    elseif a=="confirm" then
      if S.toolIndex==1 then zoom(1) elseif S.toolIndex==2 then zoom(-1)
      elseif S.toolIndex==3 then R.fit=R.fit=="width" and "page" or "width";R.zoom=1;render(false)
      elseif S.toolIndex==4 then R.textMode=not R.textMode;render(false)
      elseif S.toolIndex==5 then S.night=not S.night;save()
      elseif S.toolIndex==6 then S.jump=S.doc.page+1;S.view="jump"
      elseif S.toolIndex==7 then S.view="menu";S.menuIndex=1 end
    end
  elseif S.view=="menu" then
    if a=="down" then S.menuIndex=math.min(#menuItems(),S.menuIndex+1)
    elseif a=="up" then S.menuIndex=math.max(1,S.menuIndex-1)
    elseif a=="back" or a=="menu" then S.view=S.doc and "reader" or "browser"
    elseif a=="confirm" then activateMenu() end
  elseif S.view=="jump" then
    local delta=({left=-1,right=1,up=10,down=-10,prev=-100,next=100})[a]
    if delta then S.jump=math.max(1,math.min(S.doc.count,S.jump+delta))
    elseif a=="confirm" then S.doc.page=S.jump-1;R.clear();S.view="reader";render(false)
    elseif a=="back" then S.view="reader" end
  elseif S.view=="password" then
    if a=="left" then S.keyIndex=math.max(1,S.keyIndex-1)
    elseif a=="right" then S.keyIndex=math.min(#characters,S.keyIndex+1)
    elseif a=="up" then S.keyIndex=math.max(1,S.keyIndex-10)
    elseif a=="down" then S.keyIndex=math.min(#characters,S.keyIndex+10)
    elseif a=="text" then S.upper=not S.upper
    elseif a=="night" then S.password=S.password:sub(1,-2)
    elseif a=="confirm" and #S.password<128 then local c=characters:sub(S.keyIndex,S.keyIndex);S.password=S.password..(S.upper and c:upper() or c)
    elseif a=="menu" then openDocument(S.passwordPath,S.password)
    elseif a=="back" then S.view="browser" end
  end
end
local keys={up="up",down="down",left="left",right="right",["return"]="confirm",a="confirm",b="back",escape="back",backspace="back",q="prev",e="next",["-"]="zoom_out",["="]="zoom_in",kpadd="zoom_in",kpsubtract="zoom_out",x="text",y="night",f="favorite",tab="menu",f1="menu",f10="quit"}
function love.keypressed(key)
  local a=keys[key];if a then action(a) end
  if key=="up" or key=="down" or key=="left" or key=="right" then repeatKey=key;repeatElapsed=0;repeatAt=.30 end
end
function love.keyreleased(key) if repeatKey==key then repeatKey=nil end end
local gamepad={dpup="up",dpdown="down",dpleft="left",dpright="right",leftshoulder="prev",rightshoulder="next",start="menu",back="quit",x="favorite",y="text"}
function love.gamepadpressed(j,b)
  local a=gamepad[b]
  -- Follow the PortMaster controller labels: A confirms, B goes back.
  if b=="a" then a="confirm" end
  if b=="b" then a="back" end
  if S.view=="reader" and b=="x" then a="night" end
  if S.view=="password" then
    if b=="x" then a="text" elseif b=="y" then a="night" end
  end
  if a then action(a) end
  if b:sub(1,2)=="dp" then repeatKey=b;repeatElapsed=0;repeatAt=.30 end
end
function love.gamepadreleased(j,b) if repeatKey==b then repeatKey=nil end end
local triggers={}
function love.gamepadaxis(j,axis,value)
  if axis=="triggerleft" or axis=="triggerright" then
    local id=tostring(j:getID())..axis
    if value>.65 and not triggers[id] then action(axis=="triggerleft" and "zoom_out" or "zoom_in") end
    triggers[id]=value>.65
  end
end
function love.load()
  U.init();R.init();B.init(session)
  local bytes=love.filesystem.read("state.json")
  if bytes then local ok,v=pcall(json.decode,bytes);if ok and type(v)=="table" then state=v end end
  if type(state.progress)~="table" then state.progress={} end
  S.night=state.night==true
  S.favorites=type(state.favorites)=="table" and state.favorites or {}
  S.recent=type(state.recent)=="table" and state.recent or {}
  if I.valid(state.language) then I.set(state.language)
  else state.language=nil;chooseLanguage(true) end
end
function love.update(dt)
  B.update()
  if B.ready and not bootDone and I.valid(state.language) and S.view=="boot" then
    bootDone=true
    local test=os.getenv("PDFCRAFT_TEST_PDF")
    if test then openDocument(test) else list(state.directory or docs) end
  end
  if repeatKey then
    repeatElapsed=repeatElapsed+dt
    if repeatElapsed>=repeatAt then repeatAt=repeatAt+.10;action(gamepad[repeatKey] or keys[repeatKey]) end
  end
  if (S.view=="reader" or S.view=="tools") and not B.busy then
    for _,j in ipairs(love.joystick.getJoysticks()) do
      if j:isGamepad() then
        local x,y=j:getGamepadAxis("leftx"),j:getGamepadAxis("lefty")
        if math.abs(x)>.22 then R.panX=R.panX+x*380*dt end
        if math.abs(y)>.22 then if R.textMode then R.textY=R.textY+y*380*dt else R.panY=R.panY+y*380*dt end end
        R.clamp()
      end
    end
  end
  -- Automated desktop smoke capture; inactive in normal launches.
  if (S.view=="reader" or S.view=="tools") and not B.busy and not B.error and R.needsRender() then renderRegion() end
  local capture=os.getenv("PDFCRAFT_TEST_CAPTURE")
  if capture and not B.busy and bootDone and (S.view=="reader" or S.view=="browser") then
    S.captureWait=(S.captureWait or 0)+dt
    if S.captureWait>1 and not S.captured then
      S.captured=true
      local testView=os.getenv("PDFCRAFT_TEST_VIEW")
      if testView=="text" and not R.textMode then R.textMode=true;render(false);S.captured=false;S.captureWait=0;return end
      if testView=="menu" then S.view="menu" end
      love.graphics.captureScreenshot(function(data)
        local encoded=data:encode("png");local f=io.open(capture,"wb");if f then f:write(encoded:getString());f:close() end
        love.event.quit()
      end)
    end
  end
end
local function drawBrowser()
  U.header("PdfCraft", T("BIBLIOTECA"))
  U.rect(0,57,168,373,"panel")
  local tabs={T("Biblioteca"),T("Recentes"),T("Favoritos")}
  for i,label in ipairs(tabs) do
    local y=77+(i-1)*51
    if S.browserTab==i then U.rect(8,y-4,153,43,"selection",7);U.rect(8,y+3,4,26,"accent",2) end
    U.text((i==1 and "▣ " or i==2 and "◷ " or "☆ ")..label,18,y+5,"small",S.browserTab==i and "text" or "muted")
  end
  U.rect(15,259,136,1,"line")
  U.text(T("ARQUIVOS"),17,273,"small","muted")
  U.text(U.trim(S.directory or docs,140,"small"),17,304,"small","text")
  U.text(T("← →  categorias"),17,393,"small","muted")
  U.text(T("Documentos PDF"),184,72,"bold")
  U.text(T(#S.entries==1 and "%d item" or "%d itens",#S.entries),528,76,"small","muted")
  U.rect(178,104,451,313,"panel",8)
  if #S.entries==0 then
    U.text(T("Nenhum documento nesta categoria."),191,153,"small","muted")
  end
  for n=1,6 do
    local i=S.offset+n;local e=S.entries[i]
    if e then
      local y=110+(n-1)*50;local chosen=i==S.selected
      if chosen then U.rect(184,y,438,46,"selection",6);U.stroke(184,y,438,46,"accent",6) end
      U.rect(192,y+5,36,35,e.dir and "line" or {.57,.19,.23},5)
      U.text(e.dir and "DIR" or "PDF",195,y+14,"small","text")
      U.text(U.trim(e.name,320,"small"),240,y+6,"small",chosen and "text" or "muted")
      U.text(e.dir and T("Pasta de arquivos") or (S.favorites[e.path] and T("★ Favorito") or T("Documento PDF")),240,y+25,"small",e.dir and "muted" or "accent")
      if e.dir then U.text(">",596,y+13,"small","muted") end
    end
  end
  U.footer(T("A Abrir   B Voltar   X Favorito   START Menu"), T("← → Categorias    SELECT Sair"))
end
local function drawMenu()
  U.header("PdfCraft", T("CONFIGURAÇÕES"))
  U.text(T("Preferências e navegação"),22,71,"bold")
  for i,label in ipairs(menuItems()) do
    local y=104+(i-1)*42
    if i==S.menuIndex then U.rect(18,y-3,604,40,"selection",6);U.stroke(18,y-3,604,40,"accent",6) end
    U.text(label,32,y+5,"small",i==S.menuIndex and "text" or "muted")
  end
  U.footer(T("A Selecionar     B Voltar"), T("L/R Páginas    SELECT Sair"))
end
local function drawTools()
  U.header(T("Ferramentas"), "PDF")
  U.rect(12,68,616,348,"panel",9)
  U.text(T("VISUALIZAÇÃO"),29,80,"small","accent")
  local entries={T("Ampliar zoom"), T("Reduzir zoom"), T("Ajustar à tela / largura"), T("Modo texto"), T("Modo noturno"), T("Ir para página"), T("Mais opções")}
  for i,v in ipairs(entries) do
    local y=112+(i-1)*41
    if i==S.toolIndex then U.rect(23,y-2,591,37,"selection",6);U.stroke(23,y-2,591,37,"accent",6) end
    U.text(v,36,y+5,"small",i==S.toolIndex and "text" or "muted")
    if i==1 or i==2 then U.text(string.format("%.1fx",R.zoom),530,y+5,"small","accent") end
  end
  U.footer(T("A Aplicar    B Fechar    L/R Navegar"), T("Ferramentas de leitura e projetos"))
end
local function drawPassword()
  U.header(T("PDF protegido"))
  U.text(S.passwordHint or T("Digite a senha."),20,76,"small","muted")
  U.rect(20,103,600,38,"panel",5)
  U.text(string.rep("•",math.min(#S.password,30)),30,109,"body")
  for i=1,#characters do
    local col=(i-1)%10;local row=math.floor((i-1)/10);local x=20+col*60;local y=150+row*37
    if i==S.keyIndex then U.rect(x,y,55,33,"accent",4) else U.rect(x,y,55,33,"panel",4) end
    local c=characters:sub(i,i);if S.upper then c=c:upper() end
    U.text(c==" " and "_" or c,x+20,y+5,"body",i==S.keyIndex and "bg" or "text")
  end
  U.footer(T("A digitar  ·  X maiúsculas  ·  Y apagar  ·  START abrir"),T("B cancelar  ·  SELECT sair"))
end
local function drawLanguage()
  U.header("PdfCraft", "PORTUGUÊS / ENGLISH")
  U.text(S.firstWelcome and "Bem-vindo / Welcome" or "Idioma / Language",32,83,"title")
  U.text("Escolha seu idioma / Choose your language",32,129,"body","muted")
  local languages={"Português (Brasil)","English"}
  local hints={"Interface em português","Interface in English"}
  for i,name in ipairs(languages) do
    local y=184+(i-1)*94;local selected=i==S.languageIndex
    U.rect(32,y,576,78,selected and "selection" or "panel",9)
    if selected then U.stroke(32,y,576,78,"accent",9) end
    U.text(name,53,y+12,"bold")
    U.text(hints[i],53,y+43,"small","muted")
    if selected then U.text(">",570,y+25,"bold","accent") end
  end
  U.text(S.languageError or "Sua escolha será salva. / Your choice will be saved.",32,385,"small",S.languageError and "accent" or "muted")
  U.footer("↑ ↓  Escolher / Choose     A  Confirmar / Confirm",S.firstWelcome and "SELECT  Sair / Exit" or "B  Voltar / Back     SELECT  Sair / Exit")
end
function love.draw()
  U.begin()
  if S.view=="language" then drawLanguage()
  elseif B.error then U.message(T("Falha no motor PDF"),I.error(B.error));U.footer(T("SELECT sair"),T("Envie o arquivo log.txt para diagnóstico."))
  elseif S.view=="boot" then U.message("PdfCraft",T("Iniciando o motor de PDF…"));U.footer(T("SELECT sair"),T("Versão experimental para R36S"))
  elseif S.view=="browser" then drawBrowser()
  elseif S.view=="reader" and S.doc then
    if S.readerHUD then
      U.header(U.trim(S.doc.name,380,"title"),tostring(S.doc.page+1).."/"..tostring(S.doc.count).."   "..string.format("%.1fx",R.zoom))
    end
    R.draw(U,S.night)
    if S.readerHUD then U.footer(T("A Tela cheia  B Biblioteca  START Ferramentas"), T("L/R Página    L2/R2 Zoom    Y Texto    X Noturno")) end
  elseif S.view=="menu" then drawMenu()
  elseif S.view=="tools" then drawTools()
  elseif S.view=="password" then drawPassword()
  elseif S.view=="jump" then
    U.header(T("Ir para página"))
    U.text(tostring(S.jump).." / "..tostring(S.doc.count),250,185,"title","accent")
    U.text(T("← → 1 página     ↑ ↓ 10 páginas     L/R 100"),77,275,"body","muted")
    U.footer(T("A abrir página  ·  B cancelar"),T("SELECT sair"))
  elseif S.view=="error" then
    U.message(T("Não foi possível abrir"),S.error);U.footer(T("A ou B voltar  ·  SELECT sair"),T("O arquivo original foi preservado."))
  end
  if B.busy and not B.error then
    U.rect(170,204,300,64,"panel",10)
    U.text(T("Processando PDF…"),223,224,"body","accent")
  end
  if S.toast and love.timer.getTime()<S.toastUntil then
    U.rect(14,384,612,38,"panel",6);U.text(U.trim(S.toast,590,"small"),24,394,"small","accent")
  end
  U.finish()
end
function love.quit() save() end
