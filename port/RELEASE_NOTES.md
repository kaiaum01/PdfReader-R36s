# PdfCraft R36S — v0.2.2 / Português & English

## Português (Brasil)
Revisão da versão 0.2 para liberar a resolução de zoom no R36S com PortMaster.

### Novidades
- Guia PDF de exemplo atualizado com os controles atuais.
- Boas-vindas com escolha de português ou inglês, exibidas uma única vez após salvar.
- Interface traduzida e opção Idioma / Language no menu.
- A confirma e B volta, com migração das configurações antigas.
- Interface escura redesenhada para 640×480.
- Biblioteca com Recentes e Favoritos.
- Leitor com nome do PDF, página e indicação de zoom.
- Tela cheia e painel de ferramentas.
- Motor PDF ARM64 recompilado com zoom por região: preserva a escala solicitada e atualiza os trechos ao mover a página.

### Instalação
1. Extraia o conteúdo deste ZIP para a pasta `ports` do cartão do R36S.
2. Mantenha `PdfCraft.sh` ao lado da pasta `pdfcraft-r36s`.
3. Instale/disponibilize o PortMaster e o runtime LÖVE 11.5 no console.
4. Coloque PDFs em `pdfcraft-r36s/documents` e inicie pelo menu Ports.

### Limitações
- Funcionamento no R36S físico confirmado pelo mantenedor em 20/10/2026.
- Zoom até 32× sem o antigo limite de 2 MP / 2048 pixels por lado. O motor desenha a região visível em vez de alocar a página ampliada inteira. A memória física e a complexidade do PDF continuam influenciando o desempenho.
- Não inclui miniaturas automáticas ou busca textual no PDF. O limite de abertura de 128 MB permanece.
- Os PDFs originais não são modificados.

## English
Viewport zoom revision of PdfCraft R36S v0.2 for PortMaster.

### What's new
- Updated sample PDF guide with current controls.
- First-run welcome screen with a saved Portuguese/English language choice.
- Translated interface and an Idioma / Language menu option.
- A confirms and B goes back; previous button settings are migrated.
- Redesigned dark 640×480 interface.
- Document library with Recents and Favorites.
- Reader header with filename, page number and zoom indicator.
- Full-screen reading and tools panel.
- Rebuilt ARM64 engine with viewport rendering at the requested resolution.

### Installation
1. Extract this ZIP into the R36S SD card's `ports` folder.
2. Keep `PdfCraft.sh` next to the `pdfcraft-r36s` directory.
3. Ensure PortMaster and the LÖVE 11.5 runtime are available.
4. Put PDF files in `pdfcraft-r36s/documents` and launch from Ports.

### Known limitations
- Operation on a physical R36S confirmed by the maintainer on 2026-10-20.
- Up to 32× zoom without the old 2 MP / 2048-pixel page cap. The engine renders the visible region at the requested scale. Physical memory and PDF complexity still affect performance.
- No automatic thumbnails or in-document text search. The independent 128 MB file-opening limit remains.
- Original PDFs are not modified.
