local U={}
U.colors={bg={.036,.055,.078},panel={.070,.101,.139},muted={.57,.65,.76},text={.94,.96,1},accent={.20,.61,1},line={.14,.20,.27},card={.085,.12,.16},selection={.10,.22,.35},paper={.94,.95,.97}}
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
  U.rect(0,0,640,57,"panel")
  U.rect(16,13,26,30,"accent",5)
  U.rect(22,20,13,2,"bg");U.rect(22,26,10,2,"bg");U.rect(22,32,13,2,"bg")
  local tagWidth=tag and U.fonts.small:getWidth(tag) or 0
  U.text(U.trim(title,tag and 552-tagWidth or 550,"title"),52,12,"title")
  if tag then U.text(tag,621-tagWidth,19,"small","accent") end
end
function U.footer(a,b)
  U.rect(0,430,640,50,"panel")
  U.text(a,16,437,"small","text")
  if b then U.text(b,16,458,"small","muted") end
end
function U.begin()
  love.graphics.setCanvas(U.canvas);love.graphics.origin();love.graphics.clear(U.colors.bg)
end
function U.finish()
  love.graphics.setScissor();love.graphics.setCanvas();love.graphics.origin();love.graphics.clear(0,0,0)
  local w,h=love.graphics.getDimensions();local s=math.min(w/640,h/480)
  love.graphics.setColor(1,1,1);love.graphics.draw(U.canvas,(w-640*s)/2,(h-480*s)/2,0,s,s)
end
function U.stroke(x,y,w,h,color,r)
  U.color(color or "line");love.graphics.setLineWidth(1);love.graphics.rectangle("line",x+.5,y+.5,w-1,h-1,r or 5,r or 5)
end
function U.key(x,y,k,description,color)
  U.color(color or "accent");love.graphics.circle("line",x+9,y+9,9)
  U.text(k,x+3,y+1,"small",color or "accent")
  U.text(description,x+24,y+1,"small","text")
end
function U.message(title,message)
  U.header(title)
  love.graphics.setFont(U.fonts.body);U.color("text")
  love.graphics.printf(message,28,122,584,"left")
end
return U
