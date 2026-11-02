from docx import Document

PATH = r"output\BaoCao_Nhom3_DaChinhSua.docx"
doc = Document(PATH)

# Correct the merged total row in the labor-cost table.
cost_table = doc.tables[4]
cost_table.cell(5, 0).text = "Tổng cộng"
cost_table.cell(5, 4).text = "21.000.000"

# Correct the total project budget without assigning an artificial other cost.
budget_table = doc.tables[9]
budget_table.cell(4, 1).text = "0"
budget_table.cell(5, 1).text = "22.000.000"

# Captions and cached lists use direct text, so correct every remaining spelling instance.
for paragraph in doc.paragraphs:
    if "Patero" in paragraph.text:
        paragraph.text = paragraph.text.replace("Patero", "Pareto")

doc.save(PATH)
print(PATH)
