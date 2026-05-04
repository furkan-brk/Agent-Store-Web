# Sunum Diyagramları

Bu klasördeki Mermaid kaynaklarını SVG'ye export et — Gamma'da AI-generated görsel yetersizse SVG'leri "Replace image" ile koy.

## Render

```bash
# mmdc kurulumu
npm install -g @mermaid-js/mermaid-cli

# tek tek
mmdc -i agent-store-vs-openclaw.mmd -o agent-store-vs-openclaw.svg -t dark -b transparent
mmdc -i routing-precedence.mmd -o routing-precedence.svg -t dark -b transparent
mmdc -i isolation-tree.mmd -o isolation-tree.svg -t dark -b transparent
mmdc -i guild-master-flow.mmd -o guild-master-flow.svg -t dark -b transparent
mmdc -i legend-dag-example.mmd -o legend-dag-example.svg -t dark -b transparent
```

PowerShell toplu:
```powershell
Get-ChildItem *.mmd | ForEach-Object {
    mmdc -i $_.Name -o ($_.BaseName + ".svg") -t dark -b transparent
}
```

## Hangi diyagram nerede?

| Dosya | Slayt | Amaç |
|-------|-------|------|
| `isolation-tree.mmd` | 4 | OpenClaw 5-boyut izolasyon |
| `routing-precedence.mmd` | 5 | OpenClaw 8-kademe binding ağacı |
| `agent-store-vs-openclaw.mmd` | 11 | **Layered stack** — Agent Store on top of OpenClaw via bridge |
| `layered-mapping.mmd` | 12 | Agent Store features ↔ OpenClaw primitives mapping |
| `guild-master-flow.mmd` | 14 | Guild Master akışı |
| `legend-dag-example.mmd` | 15 | Legend örnek DAG |

## Renk paleti (PRESENTATION.md ile uyumlu)

- Background: `#0d1117`
- OpenClaw accent: `#7c3aed` (mor)
- Agent Store accent: `#f59e0b` (altın)
- Success: `#10b981` (yeşil)
- Pixel-art highlight: `#ec4899` (pembe)

## Gamma kullanımı

Gamma'nın AI image generation'ı bu diyagramların **bazılarını** yeterince iyi üretemez (özellikle DAG ve sequence). Render edilmiş SVG'leri elinin altında tut, ihtiyaç anında "Replace image" ile koy.
