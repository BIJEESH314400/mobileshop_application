import sys

path = "lib/features/products/view/products_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

new = """            Row(
              children: [
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: s.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: s.fg.withOpacity(0.35)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${product.stockQty}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: s.fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'UNITS LEFT',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: s.fg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 18, color: palette.textSecondary),
              ],
            ),"""

old = """            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    s.label,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: s.fg),
                  ),
                ),
                const SizedBox(height: 10),
                Icon(Icons.chevron_right_rounded, size: 18, color: palette.textSecondary),
              ],
            ),"""

if new not in content:
    print("NOT FOUND - nothing to revert (file may already be original)")
    sys.exit(0)

content = content.replace(new, old, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("REVERTED")
