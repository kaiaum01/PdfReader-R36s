function love.conf(t)
  t.identity = "pdfcraft-r36s"
  t.version = "11.5"
  t.console = true
  t.window.title = "PdfCraft R36S"
  t.window.width, t.window.height = 640, 480
  t.window.fullscreen = os.getenv("PDFCRAFT_WINDOWED") ~= "1"
  t.window.fullscreentype = "desktop"
  t.window.resizable = false
  t.window.vsync = 1
  t.window.highdpi = false
  t.modules.audio = false
  t.modules.sound = false
  t.modules.physics = false
  t.modules.video = false
end
