# PdfCraft R36S

**Idioma:** Português (Brasil) · [English](README.en.md)

Leitor de PDF experimental para o console portátil **R36S**, com interface em **Lua / LÖVE 11.5** e motor nativo de renderização em **Rust (ARM64)**. Esta árvore corresponde à interface **0.2 (redesign, teste)**.

> **Status:** versão experimental. A interface foi adaptada, mas a execução completa ainda precisa ser validada em um R36S físico. O programa é um **leitor**, não um editor de PDF.

## Funcionalidades

- Navegação por pastas e seleção de PDFs no armazenamento do console.
- Abertura de documentos e troca de páginas.
- Interface escura com destaques em azul, biblioteca, recentes e favoritos.
- Ajuste à tela, modo de texto, modo noturno e indicação de página.
- Zoom configurável na interface até **32×**, sujeito aos limites do renderizador.
- Continuação de leitura na última página.
- Tratamento básico de documentos protegidos por senha.

### Zoom em plantas A0: atenção

A interface aceita até 32×, mas o motor incluído nesta versão **limita o tamanho dos pixels renderizados**. Por isso, aumentar o zoom pode **não** revelar detalhes adicionais em pranchas A0. Renderização nítida por recortes (`tiles`) exige desenvolvimento e recompilação do motor Rust. Não anunciamos essa funcionalidade como concluída.

## Estrutura do repositório

```text
PdfCraft-R36S/
├── README.md                 Documentação principal
├── .gitignore
├── build.sh                  Compilação do motor ARM64
├── Cargo.toml / Cargo.lock   Workspace Rust e dependências
├── .cargo/config.toml        Configuração da arquitetura
├── apps/pdfcraft-r36s/       Motor e protocolo JSON
├── crates/                   Bibliotecas de processamento de PDF
├── assets/                   Recursos do motor (fontes não incluídas neste ZIP)
├── port/
│   ├── PdfCraft.sh           Script de inicialização PortMaster
│   └── pdfcraft-r36s/
│       ├── app/              Interface Lua (main, ui, reader, backend, json)
│       ├── port.json         Metadados PortMaster
│       └── licenses/         Licenças e avisos de terceiros
└── LICENSE-MIT / LICENSE-APACHE / NOTICE
```

## Instalação no R36S

Para instalar é necessário **compilar o motor ARM64** ou obter o binário de uma distribuição compatível; este repositório contém o código-fonte, não um pacote pré-compilado.

1. Instale ou atualize o **PortMaster** no console.
2. Instale o runtime **LÖVE 11.5** pelo gerenciamento de runtimes do PortMaster.
3. Em uma máquina Linux, compile seguindo o próximo tópico.
4. Copie **`port/PdfCraft.sh`** e toda a pasta **`port/pdfcraft-r36s/`** para a pasta **`ports`** do cartão, preservando a hierarquia.
5. Coloque seus PDFs em `ports/pdfcraft-r36s/documents/` (ou navegue pelas pastas do cartão no aplicativo).
6. Abra o **PdfCraft** no menu de Ports do console.

O script verifica a arquitetura ARM64 e a presença do runtime, inicializa o motor Rust e abre a interface Lua. Os logs de execução ficam em `pdfcraft-r36s/log.txt`.

## Compilação do motor Rust

Requisitos: Linux, `rustup`, Cargo, acesso à internet para baixar dependências e suporte ao alvo `aarch64-unknown-linux-musl`. O script `build.sh` usa **Rust 1.99.0**, `rust-lld` e compila o executável `pdfcraft-core.aarch64`.

```bash
chmod +x build.sh
./build.sh
```

Após concluir, o script copia o binário para `port/pdfcraft-r36s/bin/pdfcraft-core.aarch64`. A interface Lua não exige compilação separada. **Importante:** os arquivos de fontes tipográficas de terceiros não foram incluídos no pacote de código-fonte distribuído aqui. Se a compilação exigir recursos de `assets/fonts/`, obtenha-os das respectivas fontes oficiais, respeitando as licenças em `assets/fonts/` e `port/pdfcraft-r36s/licenses/`.

## Controles

O aplicativo é controlado por gamepad. Os comandos contextuais são exibidos no rodapé da interface. Em geral: direcional para navegar ou mover a página, **A** para confirmar, **B** para voltar, **L/R** para páginas e atalhos de zoom conforme indicados pelo leitor. O mapeamento pode variar de acordo com o firmware; o aplicativo possui opção para inverter A/B.

## Limitações conhecidas

- Zoom de alta definição por regiões para PDF A0 ainda não está integrado ao motor compilado.
- PDFs digitalizados sem camada de texto não possuem OCR.
- Edição, assinatura, mesclagem e exportação de PDFs não implementadas.
- Miniaturas automáticas na biblioteca e busca completa no documento não estão garantidas nesta versão.
- Tempo de carregamento depende da complexidade do PDF e da memória do console.
- A validação final dos comandos e desempenho deve ocorrer no hardware real.

## Testes e diagnóstico

Para verificar se o motor inicia, execute em ambiente ARM64 Linux compatível:

```bash
./port/pdfcraft-r36s/bin/pdfcraft-core.aarch64 --version
```

O comando `probe` também pode inspecionar um PDF em um ambiente de teste; veja `README-R36S.md`. Para relatar problemas, informe firmware, versão do PortMaster, tipo de PDF e trecho relevante de `log.txt` sem incluir documentos privados.

## Créditos e licenças

O motor Rust deriva de componentes do projeto **artcraft-android / storytold**, com licenciamento **MIT OU Apache-2.0**, conforme os arquivos de licença e avisos incluídos. Dependências possuem licenças próprias, listadas em `ATTRIBUTION.md`, `ATTRIBUTION.toml` e `port/pdfcraft-r36s/licenses/`. Preserve os avisos de autoria e licença ao redistribuir.

A interface e a integração R36S foram adaptadas para o projeto PdfCraft. Verifique os termos e créditos de cada componente antes de publicar binários.
