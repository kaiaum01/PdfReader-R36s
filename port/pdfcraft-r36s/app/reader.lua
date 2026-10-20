local R={x=0,y=57,w=640,h=373,zoom=1,fit="width",panX=0,panY=0,textMode=false,textY=0,textSize=24}
function R.clamp()
  if R.image then
    R.panX=math.max(0,math.min(R.panX,math.max(0,R.image:getWidth()-R.w)))
    R.panY=math.max(0,math.min(R.panY,math.max(0,R.image:getHeight()-R.h)))
  end
  R.textY=math.max(0,math.min(R.textY,math.max(0,(R.textHeight or 0)-R.h+36)))
end
function R.clear()
  if R.image then R.image:release() end
  R.image=nil;R.text="";R.lines={};R.textHeight=0;R.panX=0;R.panY=0;R.textY=0
end
function R.init()
  R.font=love.graphics.newFont("assets/Inter-Regular.ttf",R.textSize)
  R.nightShader=love.graphics.newShader([[
    vec4 effect(vec4 c, Image tex, vec2 uv, vec2 screen) {
      vec4 p=Texel(tex,uv);
      return vec4(vec3(0.92)-p.rgb*0.87,p.a)*c;
    }
  ]])
end
function R.scale(page)
  local s=(R.w-24)/page.w
  if R.fit=="page" then s=math.min(s,(R.h-16)/page.h) end
  return s*R.zoom
end
function R.loadImage(path,keepCenter)
  local f=assert(io.open(path,"rb"));local bytes=f:read("*a");f:close()
  local data=love.image.newImageData(love.filesystem.newFileData(bytes,"page.png"))
  local oldW=R.image and R.image:getWidth() or data:getWidth()
  local oldH=R.image and R.image:getHeight() or data:getHeight()
  local cx=(R.panX+R.w/2)/oldW;local cy=(R.panY+R.h/2)/oldH
  if R.image then R.image:release() end
  R.image=love.graphics.newImage(data);data:release();R.image:setFilter("linear","linear")
  if keepCenter then R.panX=cx*R.image:getWidth()-R.w/2;R.panY=cy*R.image:getHeight()-R.h/2
  else R.panX=0;R.panY=0 end
  R.clamp()
end
function R.wrap(text)
  R.text=text or R.text or ""
  if R.font then R.font:release() end
  R.font=love.graphics.newFont("assets/Inter-Regular.ttf",R.textSize)
  local width; width,R.lines=R.font:getWrap(R.text,R.w-48)
  R.lineHeight=math.floor(R.textSize*1.45)
  R.textHeight=#R.lines*R.lineHeight;R.clamp()
end
function R.draw(U,night)
  love.graphics.setScissor(R.x,R.y,R.w,R.h)
  if R.textMode then
    U.rect(R.x,R.y,R.w,R.h,night and "bg" or {.96,.95,.91})
    love.graphics.setFont(R.font);U.color(night and "text" or {.09,.13,.16})
    if not R.text or R.text=="" then
      love.graphics.printf("Esta página não tem texto selecionável.\nUse X para voltar ao PDF.",24,R.y+75,R.w-48,"center")
    else
      local first=math.max(1,math.floor(R.textY/R.lineHeight))
      for i=first,math.min(#R.lines,first+math.ceil(R.h/R.lineHeight)+2) do
        love.graphics.print(R.lines[i],24,R.y+18+(i-1)*R.lineHeight-R.textY)
      end
    end
  elseif R.image then
    U.rect(R.x,R.y,R.w,R.h,night and "bg" or {.17,.20,.22})
    local x=R.x+math.max(0,(R.w-R.image:getWidth())/2)-R.panX
    local y=R.y+math.max(0,(R.h-R.image:getHeight())/2)-R.panY
    love.graphics.setColor(1,1,1)
    if night then love.graphics.setShader(R.nightShader) end
    love.graphics.draw(R.image,x,y);love.graphics.setShader()
    if R.image:getHeight()>R.h then
      local total=R.image:getHeight();local hh=math.max(18,R.h*R.h/total)
      U.rect(634,R.y+R.panY/total*R.h,4,hh,"accent",2)
    end
  end
  love.graphics.setScissor()
end
return R
