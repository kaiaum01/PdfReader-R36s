-- User-visible strings only; PDF contents are never translated.
local I={language="pt"}
local en={
  ["%d item"]="%d item",
  ["Falha desconhecida."]="Unknown error.",
  ["Mostrando os primeiros 4.000 itens."]="Showing the first 4,000 items.",
  ["A página contém elementos que não foram exibidos."]="Some elements on this page could not be displayed.",
  ["Continuar leitura"]="Continue reading",
  ["Ir para página"]="Go to page",
  ["Alternar modo de leitura"]="Switch reading mode",
  ["Alternar modo noturno"]="Toggle night mode",
  ["Voltar para arquivos"]="Back to files",
  ["Sair"]="Exit",
  ["Pasta de documentos"]="Documents folder",
  ["Cartão: /roms"]="SD card: /roms",
  ["Segundo cartão: /roms2"]="Second SD card: /roms2",
  ["BIBLIOTECA"]="LIBRARY",
  ["Biblioteca"]="Library",
  ["Recentes"]="Recent",
  ["Favoritos"]="Favorites",
  ["ARQUIVOS"]="FILES",
  ["← →  categorias"]="← →  categories",
  ["Documentos PDF"]="PDF documents",
  ["Nenhum documento nesta categoria."]="No documents in this category.",
  ["Pasta de arquivos"]="Folder",
  ["★ Favorito"]="★ Favorite",
  ["Documento PDF"]="PDF document",
  ["A Abrir   B Voltar   X Favorito   START Menu"]="A Open   B Back   X Favorite   START Menu",
  ["← → Categorias    SELECT Sair"]="← → Categories    SELECT Exit",
  ["CONFIGURAÇÕES"]="SETTINGS",
  ["Preferências e navegação"]="Preferences and navigation",
  ["A Selecionar     B Voltar"]="A Select     B Back",
  ["L/R Páginas    SELECT Sair"]="L/R Pages    SELECT Exit",
  ["Ferramentas"]="Tools",
  ["VISUALIZAÇÃO"]="VIEW",
  ["Ampliar zoom"]="Zoom in",
  ["Reduzir zoom"]="Zoom out",
  ["Ajustar à tela / largura"]="Fit page / width",
  ["Modo texto"]="Text mode",
  ["Modo noturno"]="Night mode",
  ["Mais opções"]="More options",
  ["A Aplicar    B Fechar    L/R Navegar"]="A Apply    B Close    L/R Navigate",
  ["Ferramentas de leitura e projetos"]="Reading and drawing tools",
  ["PDF protegido"]="Password-protected PDF",
  ["Digite a senha."]="Enter the password.",
  ["A digitar  ·  X maiúsculas  ·  Y apagar  ·  START abrir"]="A Type  ·  X Shift  ·  Y Delete  ·  START Open",
  ["B cancelar  ·  SELECT sair"]="B Cancel  ·  SELECT Exit",
  ["Falha no motor PDF"]="PDF engine error",
  ["SELECT sair"]="SELECT Exit",
  ["Envie o arquivo log.txt para diagnóstico."]="Send the log.txt file for troubleshooting.",
  ["Iniciando o motor de PDF…"]="Starting the PDF engine…",
  ["Versão experimental para R36S"]="Experimental version for R36S",
  ["A Tela cheia  B Biblioteca  START Ferramentas"]="A Full screen  B Library  START Tools",
  ["L/R Página    L2/R2 Zoom    Y Texto    X Noturno"]="L/R Page    L2/R2 Zoom    Y Text    X Night",
  ["← → 1 página     ↑ ↓ 10 páginas     L/R 100"]="← → 1 page     ↑ ↓ 10 pages     L/R 100",
  ["A abrir página  ·  B cancelar"]="A Open page  ·  B Cancel",
  ["Não foi possível abrir"]="Could not open",
  ["A ou B voltar  ·  SELECT sair"]="A or B Back  ·  SELECT Exit",
  ["O arquivo original foi preservado."]="The original file was not changed.",
  ["Processando PDF…"]="Processing PDF…",
  ["%d itens"]="%d items",
  ["Esta página não tem texto selecionável.\nUse Y no controle ou X no teclado para voltar ao PDF."]="This page has no selectable text.\nPress Y on the controller or X on the keyboard to return to the PDF.",
  ["O motor PDF não iniciou. Veja log.txt na pasta do app."]="The PDF engine did not start. Check log.txt in the app folder.",
  ["O PDF demorou mais de 90 segundos. Saia e tente um arquivo menor."]="The PDF took longer than 90 seconds. Exit and try a smaller file.",
  ["Selecione um arquivo PDF."]="Select a PDF file.",
  ["Esta versão de teste aceita PDFs de até 128 MB."]="This test version supports PDF files up to 128 MB.",
  ["Arquivo acima de 128 MB."]="File exceeds 128 MB.",
  ["Este PDF precisa de senha."]="This PDF requires a password.",
  ["Senha incorreta."]="Incorrect password.",
  ["O PDF não contém páginas legíveis."]="The PDF contains no readable pages.",
  ["Limite de 20.000 páginas nesta versão."]="This version supports up to 20,000 pages.",
  ["O renderizador não conseguiu abrir este PDF."]="The renderer could not open this PDF.",
  ["Nenhum documento aberto."]="No document is open.",
  ["Página ausente."]="Missing page.",
  ["Página fora do documento."]="Page is outside the document.",
  ["Dimensões de página inválidas."]="Invalid page dimensions.",
  ["Zoom inválido."]="Invalid zoom.",
  ["Dimensão de zoom fora do intervalo de coordenadas."]="Zoom dimensions exceed the coordinate range.",
  ["Região de renderização inválida."]="Invalid rendering region.",
  ["Comando desconhecido."]="Unknown command.",
  ["Pedido excessivamente grande."]="Request is too large.",
  ["Falha interna ao processar o PDF."]="Internal error while processing the PDF.",
}
function I.valid(code) return code=="pt" or code=="en" end
function I.set(code) if I.valid(code) then I.language=code end end
function I.t(key,...)
  local value=I.language=="en" and en[key] or key
  value=value or key
  if select("#",...)>0 then return string.format(value,...) end
  return value
end
function I.error(message)
  message=tostring(message or "Falha desconhecida.")
  if I.language~="en" then return message end
  if en[message] then return en[message] end
  local field=message:match("^Campo ausente: (.*)$")
  if field then return "Missing field: "..field end
  field=message:match("^Coordenada inválida: (.*)$")
  if field then return "Invalid coordinate: "..field end
  -- Unknown engine/OS errors retain their original diagnostic text.
  return message
end
return I
