# PdfCraft R36S 0.2.2 — idiomas e zoom por região

Port experimental de leitura, com o renderizador Rust original e uma interface
nova em LÖVE 11.5. A interface Android não é executada nem emulada.

## Arquitetura

`apps/pdfcraft-r36s` cria um processo nativo persistente. Ele usa os módulos
`render`, `fonts`, `cos`, `crypt` e `filters`. A renderização de tiles em
`crates/render/src/raster.rs` foi ajustada para preservar a escala solicitada.
O parser e o documento ficam em memória entre solicitações. A interface envia
pedidos JSON por arquivos temporários e recebe respostas publicadas por rename.
O processo desenha uma região da página por vez e não altera PDFs do usuário.
O antigo teto de 2 MP / 2048 pixels por lado não é aplicado ao leitor.
As requisições render recebem x, y, width e height em pixels na escala pedida;
as respostas incluem essas coordenadas e page_width/page_height virtuais.

`port/pdfcraft-r36s/app` contém a interface, dividida em navegação, leitor,
comunicação com o motor, desenho e configuração. O lançador inicia e encerra
o processo auxiliar e usa o runtime oficial `love_11.5` do PortMaster.

## Compilar

Em Linux com rustup instalado, execute `./build.sh`. O script usa Rust 1.99.0,
alvo `aarch64-unknown-linux-musl`, linker rust-lld e CPU Cortex-A35. A biblioteca
C é incorporada ao motor para não depender da versão de glibc do firmware.
É necessário acesso à internet na primeira compilação para obter as dependências.
O Cargo.lock fixa as versões. Não é necessário Android SDK, NDK ou Java.

O resultado vai para `port/pdfcraft-r36s/bin/pdfcraft-core.aarch64`.
Copie o conteúdo de `port` conforme as instruções de ZOOM-LEIA-ME.txt.

## Verificação independente

`pdfcraft-core.aarch64 --version` identifica a arquitetura.
`pdfcraft-core.aarch64 probe arquivo.pdf pasta-de-saida` abre o PDF,
imprime metadados em JSON e grava a região inicial da primeira página em `page.png`.
Em x86_64, esse comando pode ser executado com qemu-aarch64-static.

As rotinas de teste desta revisão verificam fidelidade de recortes, zoom 32×,
deslocamento, bordas, tela cheia, troca de páginas e extração de texto. Rodar
em emulador de CPU não mede o desempenho real do R36S. A interface deve ser
validada no aparelho, especialmente mapeamento de controles e driver de vídeo.

## Escopo

Leitura e navegação apenas. Edição, OCR, câmera e síntese de voz não estão
implementados nesta versão. O código original que não participa do leitor não
está nesta árvore reduzida; o ZIP Android enviado permanece a base completa.

Licença do código original: MIT OR Apache-2.0. Licenças e atribuições mantidas.

## Idiomas e controles

A interface usa i18n.lua para português e inglês. A escolha inicial é gravada
em state.json; sem uma escolha válida, a tela de boas-vindas permanece.
A confirma e B volta. O campo legado swap é descartado na gravação, sem
apagar progresso ou favoritos. O menu permite trocar o idioma depois.
O executável nativo permanece na revisão 0.2.1 de renderização por região.
