//! Native, read-only PdfCraft renderer for the R36S frontend.
use pdfcraft_render::{DocInfo, PageRenderer, RenderConfig, RenderRequest, RequestKind};
use serde_json::{Value, json};
use std::{fs, io::Write, path::{Path, PathBuf}, sync::Arc, thread, time::Duration};

const MAX_FILE: u64 = 128 * 1024 * 1024;
const MAX_SIDE: f32 = 2048.0;
const MAX_PIXELS: f32 = 2_000_000.0;

struct Document { info: DocInfo, renderer: PageRenderer }
struct App { doc: Option<Document>, output: PathBuf }

fn err(message: impl ToString) -> Value { json!({"ok":false,"error":message.to_string()}) }
fn string<'a>(v: &'a Value, key: &str) -> Result<&'a str, String> {
    v.get(key).and_then(Value::as_str).ok_or_else(|| format!("Campo ausente: {key}"))
}
fn atomic_write(path: &Path, data: &[u8]) -> Result<(), String> {
    let tmp = path.with_extension("tmp");
    let mut f = fs::File::create(&tmp).map_err(|e| e.to_string())?;
    f.write_all(data).map_err(|e| e.to_string())?;
    drop(f);
    fs::rename(tmp, path).map_err(|e| e.to_string())
}

impl App {
    fn command(&mut self, v: &Value) -> Value {
        let result = self.handle(v);
        let mut result = match result { Ok(v) => v, Err(e) => err(e) };
        result["id"] = v.get("id").cloned().unwrap_or(json!(0));
        result
    }

    fn handle(&mut self, v: &Value) -> Result<Value, String> {
        match string(v, "op")? {
            "ping" => Ok(json!({"ok":true,"version":"0.1.0","engine":"PdfCraft 0.6.0 / hayro","arch":std::env::consts::ARCH})),
            "list" => {
                let path = fs::canonicalize(string(v,"path")?).map_err(|e| e.to_string())?;
                let mut entries = Vec::new();
                let mut truncated = false;
                for entry in fs::read_dir(&path).map_err(|e| e.to_string())? {
                    let Ok(entry) = entry else {continue};
                    let name = entry.file_name().to_string_lossy().into_owned();
                    if name.starts_with('.') {continue}
                    let Ok(meta) = entry.metadata() else {continue};
                    if !meta.is_dir() && !(meta.is_file() && name.to_lowercase().ends_with(".pdf")) {continue}
                    if entries.len() >= 4000 {truncated=true;break}
                    entries.push(json!({"name":name,"path":entry.path().to_string_lossy(),"dir":meta.is_dir(),"size":meta.len()}));
                }
                entries.sort_by(|a,b| b["dir"].as_bool().cmp(&a["dir"].as_bool()).then_with(|| {
                    a["name"].as_str().unwrap_or("").to_lowercase().cmp(&b["name"].as_str().unwrap_or("").to_lowercase())
                }));
                Ok(json!({"ok":true,"path":path.to_string_lossy(),"parent":path.parent().map(|p|p.to_string_lossy()),"entries":entries,"truncated":truncated}))
            }
            "open" => {
                let path = string(v,"path")?;
                let meta = fs::metadata(path).map_err(|e| e.to_string())?;
                if !meta.is_file() {return Err("Selecione um arquivo PDF.".into())}
                if meta.len()>MAX_FILE {return Err("Esta versão de teste aceita PDFs de até 128 MB.".into())}
                let bytes=Arc::new(fs::read(path).map_err(|e|e.to_string())?);
                if bytes.len() as u64 > MAX_FILE {return Err("Arquivo acima de 128 MB.".into())}
                let password=v.get("password").and_then(Value::as_str);
                // Release the previous document before allocating another parser.
                self.doc=None;
                let info=match pdfcraft_render::inspect(bytes.clone(),password) {
                    Ok(info)=>info,
                    Err(pdfcraft_render::OpenError::NeedsPassword)=>return Ok(json!({"ok":false,"code":"password","error":"Este PDF precisa de senha."})),
                    Err(pdfcraft_render::OpenError::WrongPassword)=>return Ok(json!({"ok":false,"code":"password","error":"Senha incorreta."})),
                    Err(e)=>return Err(e.to_string()),
                };
                if info.pages.is_empty() {return Err("O PDF não contém páginas legíveis.".into())}
                if info.pages.len()>20_000 {return Err("Limite de 20.000 páginas nesta versão.".into())}
                let pages:Vec<_>=info.pages.iter().map(|p|json!({"w":p.width,"h":p.height})).collect();
                let result=json!({"ok":true,"pages":pages,"title":info.title,"count":pages.len(),"size":meta.len()});
                let renderer=PageRenderer::new(bytes,RenderConfig {password:password.map(Arc::from),..Default::default()});
                if renderer.page_count()==0 {return Err("O renderizador não conseguiu abrir este PDF.".into())}
                self.doc=Some(Document {info,renderer});
                Ok(result)
            }
            "render" | "text" => {
                let d=self.doc.as_mut().ok_or("Nenhum documento aberto.")?;
                let page=v.get("page").and_then(Value::as_u64).ok_or("Página ausente.")? as usize;
                let info=d.info.pages.get(page).ok_or("Página fora do documento.")?;
                if !info.width.is_finite() || !info.height.is_finite() || info.width<=0.0 || info.height<=0.0 {return Err("Dimensões de página inválidas.".into())}
                let is_text=v["op"]=="text";
                let requested=v.get("scale").and_then(Value::as_f64).unwrap_or(1.0) as f32;
                if !requested.is_finite() || requested<=0.0 {return Err("Zoom inválido.".into())}
                let scale=requested.min(MAX_SIDE/info.width).min(MAX_SIDE/info.height)
                    .min((MAX_PIXELS/(info.width*info.height)).sqrt());
                let r=d.renderer.render(RenderRequest {page,scale,kind:if is_text {RequestKind::Text}else{RequestKind::Pixels},..Default::default()});
                if let Some(e)=r.error {return Err(e)}
                if is_text {
                    let text=r.text.as_ref().map(|p|p.plain_text()).unwrap_or_default();
                    let cut=text.char_indices().nth(200_000).map(|(i,_)|i).unwrap_or(text.len());
                    return Ok(json!({"ok":true,"text":&text[..cut],"truncated":cut<text.len(),"page":page}));
                }
                let mut png_bytes=Vec::new();
                {
                    let mut encoder=png::Encoder::new(&mut png_bytes,r.width,r.height);
                    encoder.set_color(png::ColorType::Rgba);
                    encoder.set_depth(png::BitDepth::Eight);
                    encoder.set_compression(png::Compression::Fast);
                    let mut writer=encoder.write_header().map_err(|e|e.to_string())?;
                    writer.write_image_data(&r.rgba).map_err(|e|e.to_string())?;
                }
                let path=self.output.join("page.png");
                atomic_write(&path,&png_bytes)?;
                Ok(json!({"ok":true,"file":path.to_string_lossy(),"width":r.width,"height":r.height,"scale":scale,"page":page,"millis":r.millis,"limited":scale+0.00001<requested,"warnings":r.warnings.len()}))
            }
            "close"=>{self.doc=None;Ok(json!({"ok":true}))},
            "quit"=>Ok(json!({"ok":true})),
            _=>Err("Comando desconhecido.".into()),
        }
    }
}

fn run() -> Result<(),String> {
    let args:Vec<_>=std::env::args().collect();
    if args.get(1).map(String::as_str)==Some("--version") {
        println!("PdfCraft R36S 0.1.0 | {} | PdfCraft 0.6.0",std::env::consts::ARCH);return Ok(())
    }
    let mode=args.get(1).map(String::as_str).unwrap_or("");
    if !["serve","probe"].contains(&mode) {return Err("Uso: pdfcraft-core serve PASTA_TEMP | probe PDF PASTA_SAIDA | --version".into())}
    let out=PathBuf::from(args.get(if mode=="serve" {2}else{3}).ok_or("Pasta de saída ausente.")?);
    fs::create_dir_all(&out).map_err(|e|e.to_string())?;
    let mut app=App {doc:None,output:out.clone()};
    if mode=="probe" {
        let path=args.get(2).ok_or("PDF ausente.")?;
        let opened=app.command(&json!({"op":"open","path":path}));
        println!("{opened}");
        if opened["ok"]!=true {return Err("Falha ao abrir PDF.".into())}
        let render=app.command(&json!({"op":"render","page":0,"scale":0.8}));
        println!("{render}");
        if render["ok"]!=true {return Err("Falha ao renderizar PDF.".into())}
        return Ok(())
    }
    atomic_write(&out.join("ready.json"),br#"{"ok":true,"version":"0.1.0"}"#)?;
    let input=out.join("request.json");
    loop {
        match fs::read(&input) {
            Ok(bytes)=>{
                fs::remove_file(&input).map_err(|e|e.to_string())?;
                let request:Value=if bytes.len()<=65536 {serde_json::from_slice(&bytes).map_err(|e|e.to_string())?}else{return Err("Pedido excessivamente grande.".into())};
                let result=std::panic::catch_unwind(std::panic::AssertUnwindSafe(||app.command(&request)))
                    .unwrap_or_else(|_|json!({"id":request["id"],"ok":false,"error":"Falha interna ao processar o PDF."}));
                atomic_write(&out.join("response.json"),result.to_string().as_bytes())?;
                if request["op"]=="quit" {break}
            },
            Err(e) if e.kind()==std::io::ErrorKind::NotFound=>thread::sleep(Duration::from_millis(40)),
            Err(e)=>return Err(e.to_string()),
        }
    }
    Ok(())
}
fn main() {
    if let Err(e)=run() {eprintln!("PdfCraft: {e}");std::process::exit(1)}
}
