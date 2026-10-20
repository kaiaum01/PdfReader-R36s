# PdfCraft R36S 0.1

Port experimental de leitura, com o renderizador Rust original e uma interface
nova em LÖVE 11.5. A interface Android não é executada nem emulada.

## Arquitetura

`apps/pdfcraft-r36s` cria um processo nativo persistente. Ele usa os módulos
originais `render`, `fonts`, `cos`, `crypt` e `filters`, preservados nesta árvore.
O parser e o documento ficam em memória entre solicitações. A interface envia
pedidos JSON por arquivos temporários e recebe respostas publicadas por rename.
O processo desenha uma página por vez e não altera PDFs do usuário.

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
Copie o conteúdo de `port` conforme as instruções de LEIA-ME.txt.

## Verificação independente

`pdfcraft-core.aarch64 --version` identifica a arquitetura.
`pdfcraft-core.aarch64 probe arquivo.pdf pasta-de-saida` abre o PDF,
imprime metadados em JSON e grava a primeira página em `page.png`.
Em x86_64, esse comando pode ser executado com qemu-aarch64-static.

As rotinas de teste desta entrega verificam abertura, renderização, extração de
texto em português, página horizontal, limite de zoom e PDF com senha. Rodar
em emulador de CPU não mede o desempenho real do R36S. A interface deve ser
validada no aparelho, especialmente mapeamento de controles e driver de vídeo.

## Escopo

Leitura e navegação apenas. Edição, OCR, câmera e síntese de voz não estão
implementados nesta versão. O código original que não participa do leitor não
está nesta árvore reduzida; o ZIP Android enviado permanece a base completa.

Licença do código original: MIT OR Apache-2.0. Licenças e atribuições mantidas.
