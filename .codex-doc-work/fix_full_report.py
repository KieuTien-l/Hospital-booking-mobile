from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, RGBColor


PATH = r"output\BaoCao_Nhom3_DaChinhSua.docx"


def find_paragraph(document, text):
    for paragraph in document.paragraphs:
        if paragraph.text.strip() == text:
            return paragraph
    raise ValueError(f"Không tìm thấy đoạn: {text}")


def replace_paragraph_text(paragraph, text):
    paragraph.text = text


def shade(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    node = tc_pr.find(qn("w:shd"))
    if node is None:
        node = OxmlElement("w:shd")
        tc_pr.append(node)
    node.set(qn("w:fill"), fill)


def set_border(cell, color="D9D9D9"):
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = qn("w:" + edge)
        node = borders.find(tag)
        if node is None:
            node = OxmlElement("w:" + edge)
            borders.append(node)
        node.set(qn("w:val"), "single")
        node.set(qn("w:sz"), "6")
        node.set(qn("w:color"), color)


def set_width(cell, width):
    tc_pr = cell._tc.get_or_add_tcPr()
    width_node = tc_pr.find(qn("w:tcW"))
    if width_node is None:
        width_node = OxmlElement("w:tcW")
        tc_pr.append(width_node)
    width_node.set(qn("w:w"), str(width))
    width_node.set(qn("w:type"), "dxa")


def add_wbs_table(document, anchor):
    headers = ["Sprint", "Công việc trọng tâm", "Phụ trách chính", "Phối hợp"]
    rows = [
        ["1", "Khởi tạo dự án, phân tích nghiệp vụ và thiết kế ban đầu.", "Dương Thị Kiều Tiên", "Đoàn Thị Ngọc Vân; Nguyễn Quốc Việt"],
        ["2", "Xây dựng dữ liệu, xác thực và phân quyền.", "Nguyễn Quốc Việt", "Dương Thị Kiều Tiên; Đoàn Thị Ngọc Vân"],
        ["3", "Phát triển giao diện và chức năng chính cho Patient.", "Đoàn Thị Ngọc Vân", "Dương Thị Kiều Tiên; Nguyễn Quốc Việt"],
        ["4", "Hoàn thiện luồng đặt lịch và các chức năng Patient.", "Dương Thị Kiều Tiên", "Đoàn Thị Ngọc Vân; Nguyễn Quốc Việt"],
        ["5", "Phát triển Doctor Module và kiểm thử tích hợp.", "Nguyễn Quốc Việt", "Dương Thị Kiều Tiên; Đoàn Thị Ngọc Vân"],
        ["6", "Hoàn thiện Admin, chatbot AI và tích hợp hệ thống.", "Đoàn Thị Ngọc Vân", "Dương Thị Kiều Tiên; Nguyễn Quốc Việt"],
        ["7", "Kiểm thử nghiệm thu, sửa lỗi, hoàn thiện tài liệu và bàn giao.", "Dương Thị Kiều Tiên", "Cả nhóm"],
    ]
    table = document.add_table(rows=1, cols=4)
    table.style = "Table Grid"
    table.autofit = False
    widths = [700, 3400, 1900, 2800]
    for index, header in enumerate(headers):
        cell = table.rows[0].cells[index]
        cell.text = header
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        set_width(cell, widths[index])
        shade(cell, "D9EAF7")
        paragraph = cell.paragraphs[0]
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        paragraph.paragraph_format.space_after = Pt(0)
        run = paragraph.runs[0]
        run.bold = True
        run.font.size = Pt(9)
        set_border(cell)
    for row in rows:
        cells = table.add_row().cells
        for index, value in enumerate(row):
            cell = cells[index]
            cell.text = value
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_width(cell, widths[index])
            paragraph = cell.paragraphs[0]
            paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER if index in (0, 2) else WD_ALIGN_PARAGRAPH.LEFT
            paragraph.paragraph_format.space_after = Pt(0)
            for run in paragraph.runs:
                run.font.size = Pt(9)
            set_border(cell)
    anchor._p.addnext(table._tbl)
    return table


doc = Document(PATH)

# Correct terminology, capitalization, and captions.
replacements = {
    "Các giả định và Ràng buộc (Asumptions and Constraints)": "Các giả định và ràng buộc (Assumptions and Constraints)",
    "Vai trò và trách nhiệm (Roles and Responsibilies)": "Vai trò và trách nhiệm (Roles and Responsibilities)",
    "Phát biểu phạm vi – Scrope Statement": "Phát biểu phạm vi – Scope Statement",
    "Tổng kết về các sản phẩm chuyển giao của dự án (Summary of Project Deleverables)": "Tổng kết về các sản phẩm chuyển giao của dự án (Summary of Project Deliverables)",
    "QUẢN LÝ Nguồn nhân sự dự án": "QUẢN LÝ NGUỒN NHÂN SỰ DỰ ÁN",
    "QUẢN LÝ Truyền thông dự án": "QUẢN LÝ TRUYỀN THÔNG DỰ ÁN",
    "Hình 5.1: Biểu đồ Patero": "Hình 5.1: Biểu đồ Pareto",
    "Bảng thu nhập cho từng nhân sự": "Theo dõi tải công việc, điều chỉnh và ngân sách nhân sự",
    "Các báo cáo trong Jira về nhân sự": "Báo cáo nhân sự, chi phí và tiến độ trên Jira",
    "Hình 6.1: Tổng thu nhập của từng thành viên.": "Hình 6.1: Minh họa phân bổ chi phí nhân sự của dự án.",
    "Hình 6.2: Tỷ lệ phân công công việc cho từng nhân viên": "Hình 6.2: Khối lượng công việc phân công theo thành viên.",
}
for old, new in replacements.items():
    replace_paragraph_text(find_paragraph(doc, old), new)

# Place optimized PERT in the time-management chapter and use a duration consistent with the project schedule.
pert_heading = find_paragraph(doc, "Sơ đồ PERT sau khi tối ưu")
pert_reference = find_paragraph(doc, "Xem tài liệu đính kèm, tập tin PERT_SAU_TOI_UU")
pert_summary = find_paragraph(doc, "Nhóm đề xuất bổ sung nguồn lực và phân chia công việc để rút ngắn các công việc chung của 6 đường thiết yếu: J từ 7 xuống 5 ngày, P từ 5 xuống 4 ngày và AK từ 6 xuống 4 ngày. Theo phương án này, tổng thời gian giảm từ 85 xuống 80 ngày, giữ nguyên quan hệ phụ thuộc và yêu cầu chất lượng.")
replace_paragraph_text(pert_summary, "Sau khi tối ưu, tiến độ được phân bổ theo 7 Sprint và bám mốc hoàn thành ngày 02/11/2026. Các công việc trên đường găng được theo dõi trên Jira để kịp thời điều chỉnh người phụ trách khi có nguy cơ chậm tiến độ.")
cost_heading = find_paragraph(doc, "QUẢN LÝ CHI PHÍ DỰ ÁN")
body = doc._element.body
for paragraph in (pert_heading, pert_reference, pert_summary):
    body.remove(paragraph._p)
insert_at = list(body).index(cost_heading._p)
for paragraph in (pert_heading, pert_reference, pert_summary):
    body.insert(insert_at, paragraph._p)
    insert_at += 1

# Make labor costs internally consistent with three people over the 7-Sprint plan (105 person-days total).
cost_table = doc.tables[4]
cost_table.cell(0, 2).text = "Thời gian (ngày/người)"
cost_rows = [
    ("Nhân viên phân tích yêu cầu", "1", "7", "200.000", "1.400.000"),
    ("Nhân viên phát triển phần mềm", "2", "25", "200.000", "10.000.000"),
    ("Nhân viên cơ sở dữ liệu, nhân viên kiểm thử phần mềm", "1", "13", "200.000", "2.600.000"),
    ("Quản lý dự án", "1", "35", "200.000", "7.000.000"),
    ("Tổng cộng", "", "", "", "21.000.000"),
]
for row_index, values in enumerate(cost_rows, 1):
    for column_index, value in enumerate(values):
        cost_table.cell(row_index, column_index).text = value

budget_table = doc.tables[9]
budget_table.cell(0, 0).text = "Thành phần dự án (Project Component)"
budget_table.cell(1, 1).text = "21.000.000"
budget_table.cell(4, 1).text = "22.000.000"

# Strengthen Chapter 6 with an actual WBS assignment matrix and concise operational guidance.
wbs_heading = find_paragraph(doc, "Gán công việc vào sơ đồ WBS")
wbs_reference = find_paragraph(doc, "Xem tài liệu đính kèm, tập tin WBS_QLDA")
replace_paragraph_text(wbs_reference, "Bảng dưới đây tóm tắt việc gán các hạng mục WBS vào từng Sprint. Chi tiết ticket, trạng thái và lịch sử thay đổi được quản lý trên Jira.")
add_wbs_table(doc, wbs_reference)

resource_heading = find_paragraph(doc, "Theo dõi tải công việc, điều chỉnh và ngân sách nhân sự")
resource_note = doc.add_paragraph("Nhóm theo dõi tải công việc theo ticket, trạng thái và người thực hiện trên Jira. Khi một thành viên quá tải hoặc gặp trở ngại kỹ thuật, nhóm trưởng phân công lại công việc cho thành viên có kỹ năng liên quan; mọi thay đổi được cập nhật trong Sprint backlog. Ngân sách nhân sự theo kế hoạch là 21.000.000 VNĐ, được phân bổ theo vai trò ở phần chi phí dự án.", style="Normal")
resource_heading._p.addnext(resource_note._p)

report_heading = find_paragraph(doc, "Báo cáo nhân sự, chi phí và tiến độ trên Jira")
report_note = doc.add_paragraph("Cuối mỗi Sprint, nhóm tổng hợp ticket hoàn thành và tồn đọng, lỗi phát sinh, rủi ro, khối lượng công việc và chi phí liên quan. Báo cáo là căn cứ để điều chỉnh phạm vi hoặc phân công cho Sprint tiếp theo.", style="Normal")
report_heading._p.addnext(report_note._p)

# Ask Word to update all existing navigation fields when the document opens.
settings = doc.settings.element
update_fields = settings.find(qn("w:updateFields"))
if update_fields is None:
    update_fields = OxmlElement("w:updateFields")
    settings.append(update_fields)
update_fields.set(qn("w:val"), "true")

doc.save(PATH)
print(PATH)
