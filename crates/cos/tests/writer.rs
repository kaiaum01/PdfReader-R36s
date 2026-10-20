//! Full saves with object streams and cross-reference streams (M1.9), read back by our parser
//! and by hayro, and incremental saves stacked on top of them.

use std::sync::Arc;

use pdfcraft_cos::{Dict, Document, ObjRef, Object, SaveOptions, Stream, write_full, write_incremental};

/// Four pages, a shared font, document info with a non-ASCII title.
fn fixture() -> Vec<u8> {
    let mut objs: Vec<String> = vec!["<< /Type /Catalog /Pages 2 0 R >>".into()];
    let kids: Vec<String> = (0..4).map(|i| format!("{} 0 R", 4 + 2 * i)).collect();
    objs.push(format!("<< /Type /Pages /Kids [{}] /Count 4 /MediaBox [0 0 200 300] >>", kids.join(" ")));
    objs.push("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>".into());
    for i in 0..4 {
        objs.push(format!("<< /Type /Page /Parent 2 0 R /Contents {} 0 R /Resources << /Font << /F1 3 0 R >> >> >>", 5 + 2 * i));
        let body = format!("BT /F1 24 Tf 20 150 Td (Page {}) Tj ET", i + 1);
        objs.push(format!("<< /Length {} >>\nstream\n{body}\nendstream", body.len()));
    }
    objs.push("<< /Title (Caf\\351 \\(draft\\)) >>".into());
    let mut out = b"%PDF-1.4\n".to_vec();
    let mut offsets = Vec::new();
    for (i, o) in objs.iter().enumerate() {
        offsets.push(out.len());
        out.extend_from_slice(format!("{} 0 obj\n{o}\nendobj\n", i + 1).as_bytes());
    }
    let xref = out.len();
    out.extend_from_slice(format!("xref\n0 {}\n0000000000 65535 f \n", objs.len() + 1).as_bytes());
    for o in offsets {
        out.extend_from_slice(format!("{o:010} 00000 n \n").as_bytes());
    }
    out.extend_from_slice(
        format!("trailer\n<< /Size {} /Root 1 0 R /Info {} 0 R >>\nstartxref\n{xref}\n%%EOF\n", objs.len() + 1, objs.len()).as_bytes(),
    );
    out
}

fn title(doc: &Document) -> Vec<u8> {
    let info = doc.resolve(doc.trailer().get(b"Info").unwrap());
    info.as_dict().unwrap().get(b"Title").unwrap().as_string().unwrap().bytes.clone()
}

fn hayro_pages(bytes: &[u8]) -> usize {
    hayro_syntax::Pdf::new(Arc::new(bytes.to_vec())).expect("hayro opens").pages().len()
}

#[test]
fn full_save_packs_objects_into_object_streams() {
    let doc = Document::open(Arc::new(fixture())).unwrap();
    let packed = write_full(&doc, &SaveOptions::default()).unwrap();
    let text = String::from_utf8_lossy(&packed);
    assert!(packed.starts_with(b"%PDF-1.5"), "object streams need PDF 1.5");
    assert!(text.contains("/ObjStm") && text.contains("/XRef"));
    assert!(!text.contains("\nxref\n"), "no classic table");
    assert!(!text.contains("/Type /Catalog") && !text.contains("/Type/Catalog"), "the catalog is compressed");

    let back = Document::open(Arc::new(packed.clone())).unwrap();
    assert!(back.repair_log().is_empty(), "{:?}", back.repair_log());
    assert_eq!(title(&back), b"Caf\xe9 (draft)");
    assert_eq!(hayro_pages(&packed), 4);

    let classic = write_full(&doc, &SaveOptions { object_streams: false, ..SaveOptions::default() }).unwrap();
    assert!(classic.starts_with(b"%PDF-1.4"));
    assert!(String::from_utf8_lossy(&classic).contains("\nxref\n"));
    assert_eq!(hayro_pages(&classic), 4);
}

#[test]
fn incremental_saves_stack_on_an_xref_stream_file() {
    let doc = Document::open(Arc::new(fixture())).unwrap();
    let packed = Arc::new(write_full(&doc, &SaveOptions::default()).unwrap());
    let mut doc = Document::open(packed.clone()).unwrap();
    // Edit an object that lives in an object stream.
    let info = doc.trailer().reference(b"Info").unwrap();
    doc.update_dict(info, |d: &mut Dict| d.set(b"Title".to_vec(), Object::String(pdfcraft_cos::PdfString { bytes: b"Second".to_vec(), hex: false })))
        .unwrap();
    let added = doc.add(Object::Int(42));
    let updated = write_incremental(&doc, &SaveOptions::default()).unwrap();
    assert!(updated.starts_with(&packed), "an incremental save only appends");
    let tail = String::from_utf8_lossy(&updated[packed.len()..]);
    assert!(tail.contains("/XRef") && tail.contains("/Prev"), "the update uses an xref stream too");

    let back = Document::open(Arc::new(updated.clone())).unwrap();
    assert!(back.repair_log().is_empty(), "{:?}", back.repair_log());
    assert_eq!(title(&back), b"Second");
    assert_eq!(*back.get(ObjRef::new(added.num, 0)), Object::Int(42));
    assert_eq!(back.revisions().len(), 2);
    assert_eq!(hayro_pages(&updated), 4);
}

/// The revision is joined to the original once, at its exact size. A revision of more than a few
/// kilobytes used to outgrow the buffer: the whole original was copied a second time, and the
/// result kept up to as much again unused for as long as it was the document's working bytes.
#[test]
fn incremental_saves_are_allocated_at_their_exact_size() {
    let table = Arc::new(fixture());
    let stream = Arc::new(write_full(&Document::open(table.clone()).unwrap(), &SaveOptions::default()).unwrap());
    let no_newline = Arc::new(fixture().trim_ascii_end().to_vec());
    for original in [table, stream, no_newline] {
        let mut doc = Document::open(original.clone()).unwrap();
        let data: Vec<u8> = (0..100_000u32).map(|i| (i % 251) as u8).collect();
        let added = doc.add(Object::Stream(Stream { dict: Dict::new(), raw: data.clone().into() }));
        let updated = write_incremental(&doc, &SaveOptions::default()).unwrap();
        assert_eq!(updated.capacity(), updated.len());
        assert!(updated.starts_with(&original), "an incremental save only appends");
        let back = Document::open(Arc::new(updated.clone())).unwrap();
        assert!(back.repair_log().is_empty(), "{:?}", back.repair_log());
        match &*back.get(added) {
            Object::Stream(s) => assert_eq!(*s.raw, data),
            other => panic!("{other:?}"),
        }
        assert_eq!(hayro_pages(&updated), 4);
    }
}

/// A full save grows its buffer as it writes, so it used to end with up to as much again unused,
/// kept alive with the document's working bytes. It now ends at its exact size.
#[test]
fn full_saves_are_allocated_at_their_exact_size() {
    let mut doc = Document::open(Arc::new(fixture())).unwrap();
    let data: Vec<u8> = (0..100_000u32).map(|i| (i % 251) as u8).collect();
    let added = doc.add(Object::Stream(Stream { dict: Dict::new(), raw: Arc::new(data.clone()).into() }));
    let root = doc.root().unwrap();
    doc.update_dict(root, |d| d.set(b"Extra".to_vec(), Object::Ref(added))).unwrap();
    for object_streams in [true, false] {
        let full = write_full(&doc, &SaveOptions { object_streams, ..SaveOptions::default() }).unwrap();
        assert_eq!(full.capacity(), full.len(), "object streams: {object_streams}");
        let back = Document::open(Arc::new(full.clone())).unwrap();
        assert!(back.repair_log().is_empty(), "{:?}", back.repair_log());
        let extra = back.dict(&Object::Ref(back.root().unwrap())).and_then(|d| d.get(b"Extra").cloned()).unwrap();
        match &*back.resolve(&extra) {
            Object::Stream(s) => assert_eq!(*s.raw, data),
            other => panic!("{other:?}"),
        }
        assert_eq!(hayro_pages(&full), 4);
    }
}

#[test]
fn qpdf_accepts_object_stream_output() {
    let Ok(out) = std::process::Command::new("qpdf").arg("--version").output() else {
        eprintln!("qpdf not installed: skipped");
        return;
    };
    assert!(out.status.success());
    let doc = Document::open(Arc::new(fixture())).unwrap();
    let packed = write_full(&doc, &SaveOptions::default()).unwrap();
    let path = std::env::temp_dir().join(format!("pdfcraft-objstm-{}.pdf", std::process::id()));
    std::fs::write(&path, &packed).unwrap();
    let check = std::process::Command::new("qpdf").arg("--check").arg(&path).output().unwrap();
    let _ = std::fs::remove_file(&path);
    let report = String::from_utf8_lossy(&check.stdout);
    assert!(check.status.success() && report.contains("No syntax or stream encoding errors"), "{report}");
}

#[test]
fn the_catalog_of_an_encrypted_document_stays_outside_object_streams() {
    // Acrobat reports an encrypted file as damaged when its catalog is in an object stream,
    // before asking for the password (#774). Unencrypted output still packs the catalog.
    fn root_is_packed(bytes: &[u8], password: Option<&str>) -> bool {
        let doc = Document::open_with_password(Arc::new(bytes.to_vec()), password).unwrap();
        let root = doc.trailer().reference(b"Root").unwrap();
        let direct = format!("\n{} 0 obj", root.num);
        !bytes.windows(direct.len()).any(|w| w == direct.as_bytes())
    }
    let plain = Document::open(Arc::new(fixture())).unwrap();
    assert!(root_is_packed(&write_full(&plain, &SaveOptions::default()).unwrap(), None), "unencrypted: catalog in an object stream");
    let mut enc = plain.clone();
    enc.set_encryption(&pdfcraft_cos::NewEncryption {
        algorithm: pdfcraft_cos::Algorithm::Aes256,
        user_password: "user",
        owner_password: "owner",
        permissions: -4,
        encrypt_metadata: true,
        seed: [7; 32],
    })
    .unwrap();
    let packed = write_full(&enc, &SaveOptions::default()).unwrap();
    assert!(!root_is_packed(&packed, Some("user")), "encrypted: catalog must be a standalone object");
    let back = Document::open_with_password(Arc::new(packed.clone()), Some("user")).expect("reopens");
    assert!(back.repair_log().is_empty(), "{:?}", back.repair_log());
    assert_eq!(title(&back), b"Caf\xe9 (draft)");
}

#[test]
fn objects_referenced_by_the_encrypt_dictionary_stay_outside_object_streams() {
    // Encrypt a document, then move its crypt filters into indirect objects, as some producers
    // do (pdf.js issue7665). A full save must keep them readable before decryption.
    let doc = Document::open(Arc::new(fixture())).unwrap();
    let mut enc = doc.clone();
    enc.set_encryption(&pdfcraft_cos::NewEncryption {
        algorithm: pdfcraft_cos::Algorithm::Aes256,
        user_password: "",
        owner_password: "owner",
        permissions: -4,
        encrypt_metadata: true,
        seed: [7; 32],
    })
    .unwrap();
    let bytes = Arc::new(write_full(&enc, &SaveOptions { object_streams: false, ..SaveOptions::default() }).unwrap());
    let mut doc = Document::open(bytes).unwrap();
    let enc_ref = doc.trailer().reference(b"Encrypt").expect("indirect /Encrypt");
    let cf = doc.get(enc_ref).as_dict().unwrap().get(b"CF").cloned().unwrap();
    let cf_ref = doc.add(cf);
    doc.update_dict(enc_ref, |d| d.set(b"CF".to_vec(), Object::Ref(cf_ref))).unwrap();
    let packed = write_full(&doc, &SaveOptions::default()).unwrap();
    let back = Document::open(Arc::new(packed.clone())).expect("reopens");
    assert!(back.repair_log().is_empty(), "{:?}", back.repair_log());
    assert_eq!(title(&back), b"Caf\xe9 (draft)");
    assert_eq!(hayro_pages(&packed), 4);
}

#[test]
fn page_tree_loops_in_object_streams_do_not_crash_readers() {
    // pdf.js Pages-tree-refs.pdf: /Kids 3 → 4 → 5 → 3. Written faithfully into object streams,
    // it used to overflow hayro-syntax's stack (vendored patch: cycle guard in `resolve_pages`).
    let objs = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [6 0 R 3 0 R] /Count 2 /MediaBox [0 0 595 842] >>",
        "<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
        "<< /Type /Pages /Kids [5 0 R] /Count 1 >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R >>",
    ];
    let mut out = b"%PDF-1.7\n".to_vec();
    let mut offsets = Vec::new();
    for (i, o) in objs.iter().enumerate() {
        offsets.push(out.len());
        out.extend_from_slice(format!("{} 0 obj\n{o}\nendobj\n", i + 1).as_bytes());
    }
    let xref = out.len();
    out.extend_from_slice(format!("xref\n0 {}\n0000000000 65535 f \n", objs.len() + 1).as_bytes());
    for o in offsets {
        out.extend_from_slice(format!("{o:010} 00000 n \n").as_bytes());
    }
    out.extend_from_slice(format!("trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n", objs.len() + 1).as_bytes());
    let doc = Document::open(Arc::new(out)).unwrap();
    let packed = write_full(&doc, &SaveOptions::default()).unwrap();
    assert!(String::from_utf8_lossy(&packed).contains("/ObjStm"));
    assert_eq!(hayro_pages(&packed), 1);
}

/// Whole-file scans read each object stream's objects together (the objects stored in the file
/// first): by number, objects of different streams interleave, and a stream too big for the
/// scan's cache was decoded again for each of its objects (96 decodes of a 509 MB stream in a
/// 350 MB textbook: 44 s to list its signatures).
#[test]
fn scans_read_each_object_stream_together() {
    let mut doc = Document::open(Arc::new(fixture())).unwrap();
    let filler: Vec<_> = (0..600).map(|i| Object::Ref(doc.add(Object::Int(i)))).collect();
    doc.update_dict(doc.root().unwrap(), |catalog| catalog.set(b"Filler".to_vec(), Object::Array(filler))).unwrap();
    let packed = write_full(&doc, &SaveOptions::default()).unwrap();
    let back = Document::open(Arc::new(packed)).unwrap();
    let order = back.scan_order();
    let mut sorted = order.clone();
    sorted.sort_unstable();
    assert_eq!(sorted, back.object_numbers(), "every object, once");
    let keys: Vec<_> = order
        .iter()
        .map(|&n| match back.xref_entry(n) {
            Some(pdfcraft_cos::XrefEntry::InStream { stream, index }) => (1u8, stream, index),
            _ => (0, n, 0),
        })
        .collect();
    assert!(keys.windows(2).all(|w| w[0] < w[1]), "file objects by number, then stream by stream");
    assert!(keys.iter().any(|k| k.0 == 1), "the save packed objects into object streams");
    let scanned: Vec<u32> = back.scan_objects().map(|(r, _)| r.num).collect();
    assert_eq!(scanned, order);
}

/// A scan for a key parses only the objects whose text names it, in object streams and in the
/// file alike, and always the edited ones (a tagged textbook's 509 MB structure tree is never
/// parsed when looking for timestamps).
#[test]
fn a_scan_for_a_key_parses_only_objects_that_name_it() {
    let mut doc = Document::open(Arc::new(fixture())).unwrap();
    let mut marked = Dict::new();
    marked.set(b"ByteRange".to_vec(), Object::Array(vec![Object::Int(0)]));
    let kept = doc.add(Object::Dict(marked.clone()));
    let filler: Vec<_> = (0..300).map(|i| Object::Ref(doc.add(Object::Int(i)))).collect();
    // a full save writes what the catalog reaches
    doc.update_dict(doc.root().unwrap(), |catalog| {
        catalog.set(b"Marked".to_vec(), Object::Ref(kept));
        catalog.set(b"Filler".to_vec(), Object::Array(filler));
    })
    .unwrap();
    let packed = write_full(&doc, &SaveOptions::default()).unwrap();
    let mut back = Document::open(Arc::new(packed)).unwrap();
    // a full save renumbers: find the marked dictionary the long way
    let packed_one = back.scan_objects().find(|(_, o)| o.as_dict().is_some_and(|d| d.get(b"ByteRange").is_some())).unwrap().0;
    assert!(matches!(back.xref_entry(packed_one.num), Some(pdfcraft_cos::XrefEntry::InStream { .. })), "in an object stream");
    let found: Vec<u32> = back.scan_objects_mentioning(b"ByteRange").map(|(r, _)| r.num).collect();
    assert_eq!(found, vec![packed_one.num]);
    // an unsaved object is always read
    let edited = back.add(Object::Dict(marked));
    let found: Vec<u32> = back.scan_objects_mentioning(b"ByteRange").map(|(r, _)| r.num).collect();
    assert!(found.contains(&packed_one.num) && found.contains(&edited.num));
    assert!(back.scan_objects_mentioning(b"NoSuchKey").all(|(r, _)| r == edited), "only the edited one");
}
