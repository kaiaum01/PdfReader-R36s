local U={}
U.colors={bg={.035,.060,.085},panel={.065,.10,.14},muted={.54,.64,.71},text={.91,.94,.95},accent={.40,.90,.73},line={.14,.21,.26}}
function U.init()
  U.fonts={small=love.graphics.newFont("assets/Inter-Regular.ttf",16),body=love.graphics.newFont("assets/Inter-Regular.ttf",20),title=love.graphics.newFont("assets/Inter-SemiBold.ttf",25),bold=love.graphics.newFont("assets/Inter-SemiBold.ttf",20)}
  U.canvas=love.graphics.newCanvas(640,480)
end
function U.color(c,a)
  if type(c)=="string" then c=U.colors[c] end
  love.graphics.setColor(c[1],c[2],c[3],a or 1)
end
function U.text(s,x,y,font,color)
  love.graphics.setFont(U.fonts[font or "body"]);U.color(color or "text");love.graphics.print(s or "",x,y)
end
function U.trim(s,width,font)
  local f=U.fonts[font or "body"];s=s or ""
  if f:getWidth(s)<=width then return s end
  local utf8=require("utf8")
  while #s>0 and f:getWidth(s.."…")>width do
    local at=utf8.offset(s,-1);s=s:sub(1,(at or 1)-1)
  end
  return s.."…"
end
function U.rect(x,y,w,h,c,r)
  U.color(c);love.graphics.rectangle("fill",x,y,w,h,r or 0,r or 0)
end
function U.header(title,tag)
  U.rect(0,0,640,66,"panel")
  U.rect(20,18,25,30,"accent",5)
  U.rect(26,26,13,2,"bg");U.rect(26,32,10,2,"bg");U.rect(26,38,13,2,"bg")
  local tagWidth=tag and U.fonts.small:getWidth(tag) or 0
  U.text(U.trim(title,tag and 552-tagWidth or 550,"title"),58,19,"title")
  if tag then U.text(tag,620-tagWidth,25,"small","accent") end
end
function U.footer(a,b)
  U.rect(0,428,640,52,"panel")
  U.text(a,18,436,"small","text")
  if b then U.text(b,18,458,"small","muted") end
end
function U.begin()
  love.graphics.setCanvas(U.canvas);love.graphics.origin();love.graphics.clear(U.colors.bg)
end
function U.finish()
  love.graphics.setScissor();love.graphics.setCanvas();love.graphics.origin();love.graphics.clear(0,0,0)
  local w,h=love.graphics.getDimensions();local s=math.min(w/640,h/480)
  love.graphics.setColor(1,1,1);love.graphics.draw(U.canvas,(w-640*s)/2,(h-480*s)/2,0,s,s)
end
function U.message(title,message)
  U.header(title)
  love.graphics.setFont(U.fonts.body);U.color("text")
  love.graphics.printf(message,28,122,584,"left")
end
return U
