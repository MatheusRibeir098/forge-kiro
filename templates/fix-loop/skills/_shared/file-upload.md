---
name: file-upload
description: Upload de arquivos com extração de conteúdo. Usar ao implementar upload de PDF, DOCX, imagens.
---

# Upload e Extração de Arquivos

## Frontend — Upload com React

```tsx
// Input file hidden + área de drop
const fileInputRef = useRef<HTMLInputElement>(null);
const [files, setFiles] = useState<File[]>([]);

function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
  // IMPORTANTE: copiar antes de limpar o input
  const newFiles = Array.from(e.target.files ?? []);
  if (newFiles.length > 0) setFiles(prev => [...prev, ...newFiles]);
  if (fileInputRef.current) fileInputRef.current.value = '';
}

// Área visual clicável
<div onClick={() => fileInputRef.current?.click()}
  className="border-2 border-dashed rounded-xl p-6 text-center cursor-pointer
    hover:border-brand-400 hover:bg-brand-50/30">
  <p>Arraste ou clique para selecionar</p>
</div>
<input ref={fileInputRef} type="file" accept=".pdf,.docx,.png,.jpg" multiple className="hidden"
  onChange={handleFileSelect} />

// Lista de arquivos com remoção
{files.map((file, i) => (
  <div key={i} className="flex items-center gap-3">
    <span className="truncate">{file.name}</span>
    <span className="text-xs">{formatFileSize(file.size)}</span>
    <button onClick={() => setFiles(f => f.filter((_, j) => j !== i))}>✕</button>
  </div>
))}
```

## Frontend — Envio com FormData

```tsx
// NUNCA setar Content-Type manualmente com FormData
const formData = new FormData();
formData.append('title', title);
if (text) formData.append('text', text);
for (const file of files) formData.append('files', file);
const { data } = await api.post('/endpoint', formData); // Axios auto-seta boundary
```

## Backend — Recebimento com Multer

```ts
import multer from 'multer';
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024, files: 10 }
});

router.post('/upload', upload.array('files', 10), async (req, res) => {
  const files = (req.files as Express.Multer.File[]) || [];
  for (const file of files) {
    // file.buffer, file.mimetype, file.originalname
  }
});
```

## Backend — Extração de Texto

```ts
// PDF — pdf-parse (v2 precisa de Uint8Array)
import { PDFParse } from 'pdf-parse';
const parser = new PDFParse(new Uint8Array(buffer));
await parser.load();
const result = await parser.getText();

// DOCX — mammoth
import mammoth from 'mammoth';
const result = await mammoth.extractRawText({ buffer });
// result.value contém o texto

// Imagem OCR — tesseract.js
import { createWorker } from 'tesseract.js';
const worker = await createWorker('por+eng');
const result = await worker.recognize(buffer);
await worker.terminate();
// result.data.text contém o texto
```

## Armadilhas

- `pdf-parse` v2 exige `Uint8Array`, não `Buffer`
- FormData + Axios: NÃO setar `Content-Type` manualmente
- `e.target.files` é referência ao FileList do input — copiar com `Array.from()` antes de limpar
- Slides PDF com imagens: só extrai texto, não imagens
- OCR é lento (~10-30s por imagem) — avisar o usuário
