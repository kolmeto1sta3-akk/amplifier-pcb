#!/bin/bash
# Проверка ERC/DRC и генерация производственных файлов для проекта amplifier
# Запуск из любой папки:  ./scripts/check.sh
set -e
cd "$(dirname "$0")/.."

# Путь к kicad-cli (macOS). Можно переопределить: KICAD_CLI=/path/to/kicad-cli ./scripts/check.sh
CLI="${KICAD_CLI:-/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli}"
command -v kicad-cli >/dev/null 2>&1 && [ -z "$KICAD_CLI" ] && CLI=kicad-cli

P=amplifier
OUT=output
rm -rf "$OUT"
mkdir -p "$OUT/gerbers"

echo "=== 1/5 ERC (электрические правила схемы) ==="
"$CLI" sch erc --severity-error --exit-code-violations \
    -o "$OUT/erc.rpt" "$P.kicad_sch" \
  || { echo "ERC: найдены ошибки, см. $OUT/erc.rpt"; exit 1; }

echo "=== 2/5 DRC (проектные нормы платы + соответствие схеме) ==="
"$CLI" pcb drc --severity-error --schematic-parity --exit-code-violations \
    -o "$OUT/drc.rpt" "$P.kicad_pcb" \
  || { echo "DRC: найдены ошибки, см. $OUT/drc.rpt"; exit 1; }

echo "=== 3/5 Gerber + сверловка ==="
"$CLI" pcb export gerbers -o "$OUT/gerbers/" \
    --layers F.Cu,B.Cu,F.Paste,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts \
    "$P.kicad_pcb"
"$CLI" pcb export drill -o "$OUT/gerbers/" --format excellon "$P.kicad_pcb"
(cd "$OUT" && zip -rq "${P}_gerbers.zip" gerbers)

echo "=== 4/5 BOM (перечень элементов) ==="
"$CLI" sch export bom -o "$OUT/${P}_BOM.csv" \
    --fields 'Reference,Value,Footprint,Manufacturer_Part_Number,${QUANTITY}' \
    --labels 'Поз. обозначение,Номинал,Корпус,Партномер,Кол.' \
    --group-by 'Value,Footprint,Manufacturer_Part_Number' \
    --sort-field Reference \
    "$P.kicad_sch"

echo "=== 5/5 PDF схемы ==="
"$CLI" sch export pdf -o "$OUT/${P}_schematic.pdf" "$P.kicad_sch"

echo
echo "Готово. Результаты в папке $OUT/:"
ls -1 "$OUT"
