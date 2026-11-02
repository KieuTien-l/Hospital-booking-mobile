from copy import deepcopy

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, RGBColor


SOURCE = r".codex-doc-work\BaoCao_Nhom3_Chuong6.docx"
OUTPUT = r".codex-doc-work\BaoCao_Nhom3_Chuong6.docx"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_border(cell, color="D9D9D9", size="6"):
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = "w:" + edge
        element = borders.find(qn(tag))
        if element is None:
            element = OxmlElement(tag)
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), size)
        element.set(qn("w:space"), "0")
        element.set(qn("w:color"), color)


def set_cell_margins(cell, top=90, start=100, bottom=90, end=100):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for side, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn("w:" + side))
        if node is None:
            node = OxmlElement("w:" + side)
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    table_header = OxmlElement("w:tblHeader")
    table_header.set(qn("w:val"), "true")
    tr_pr.append(table_header)


def set_col_width(cell, twips):
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_w = tc_pr.find(qn("w:tcW"))
    if tc_w is None:
        tc_w = OxmlElement("w:tcW")
        tc_pr.append(tc_w)
    tc_w.set(qn("w:w"), str(twips))
    tc_w.set(qn("w:type"), "dxa")


def put_cell_text(cell, value, header=False, center=False):
    cell.text = ""
    paragraph = cell.paragraphs[0]
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER if center else WD_ALIGN_PARAGRAPH.LEFT
    paragraph.paragraph_format.space_after = Pt(0)
    paragraph.paragraph_format.space_before = Pt(0)
    run = paragraph.add_run(value)
    run.bold = header
    run.font.size = Pt(10)
    if header:
        run.font.color.rgb = RGBColor(255, 255, 255)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    set_cell_border(cell)
    set_cell_margins(cell)


def add_table(document, headers, rows, widths=None, centered_columns=()):
    table = document.add_table(rows=1, cols=len(headers))
    table.autofit = False
    table.style = "Table Grid"
    header_row = table.rows[0]
    set_repeat_table_header(header_row)
    for index, text in enumerate(headers):
        cell = header_row.cells[index]
        put_cell_text(cell, text, header=True, center=True)
        set_cell_shading(cell, "1F4E78")
        if widths:
            set_col_width(cell, widths[index])
    for row_values in rows:
        cells = table.add_row().cells
        for index, value in enumerate(row_values):
            put_cell_text(cells[index], str(value), center=index in centered_columns)
            if widths:
                set_col_width(cells[index], widths[index])
    for row in table.rows:
        for cell in row.cells:
            set_cell_border(cell)
    return table


def add_caption(document, text):
    paragraph = document.add_paragraph(style="Style2")
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_before = Pt(3)
    paragraph.paragraph_format.space_after = Pt(7)
    paragraph.add_run(text)
    return paragraph


def add_body(document, text):
    paragraph = document.add_paragraph(style="Normal")
    paragraph.paragraph_format.space_after = Pt(6)
    paragraph.add_run(text)
    return paragraph


def add_heading(document, text, level):
    paragraph = document.add_paragraph(text, style=f"Heading {level}")
    paragraph.paragraph_format.space_before = Pt(9 if level == 2 else 7)
    paragraph.paragraph_format.space_after = Pt(5)
    return paragraph


def remove_existing_chapter(document):
    start = None
    for paragraph in document.paragraphs:
        if paragraph.text.strip().upper() == "QUẢN LÝ NGUỒN NHÂN SỰ DỰ ÁN":
            start = paragraph._p
            break
    if start is None:
        raise ValueError("Không tìm thấy điểm bắt đầu Chương 6.")
    body = document._element.body
    children = list(body)
    start_index = children.index(start)
    for child in children[start_index:]:
        if child.tag == qn("w:sectPr"):
            break
        body.remove(child)


doc = Document(SOURCE)
remove_existing_chapter(doc)

page_break = doc.add_paragraph()
page_break.add_run().add_break(WD_BREAK.PAGE)

add_heading(doc, "QUẢN LÝ NGUỒN NHÂN SỰ DỰ ÁN", 1)

add_heading(doc, "6.1. Ước lượng số lượng nhân sự", 2)
add_body(
    doc,
    "Dự án HealWay được thực hiện trong 7 Sprint, từ ngày 14/09/2026 đến ngày 02/11/2026. "
    "Nhóm bố trí 3 thành viên làm việc xuyên suốt dự án. Do quy mô nhóm nhỏ, mỗi thành viên kiêm nhiệm "
    "nhiều vai trò nhưng vẫn có người chịu trách nhiệm chính cho từng nhóm công việc."
)
add_table(
    doc,
    ["Vai trò", "Số lượng", "Phạm vi trách nhiệm chính"],
    [
        ["Quản lý dự án", "1", "Lập kế hoạch Sprint, điều phối công việc, theo dõi tiến độ, quản lý rủi ro và trao đổi với các bên liên quan."],
        ["Phân tích và thiết kế", "2", "Làm rõ yêu cầu, thiết kế luồng nghiệp vụ, giao diện và dữ liệu; hỗ trợ kiểm thử nghiệm thu."],
        ["Phát triển và kiểm thử", "3", "Phát triển Flutter/Dart, tích hợp Firebase và API, kiểm thử chức năng, sửa lỗi và hoàn thiện bản bàn giao."],
    ],
    widths=[2100, 900, 5800],
    centered_columns=(1,),
)
add_caption(doc, "Bảng 6.1: Ước lượng nguồn nhân lực dự án HealWay.")

add_heading(doc, "6.2. Sơ đồ tổ chức nhân sự dự án", 2)
add_body(
    doc,
    "Cơ cấu tổ chức được thiết kế theo mô hình nhóm gọn nhẹ. Quản lý dự án chịu trách nhiệm điều phối chung; "
    "các thành viên phối hợp chéo giữa phân tích, thiết kế, phát triển, dữ liệu và kiểm thử để bảo đảm tiến độ từng Sprint."
)
add_table(
    doc,
    ["Cấp tổ chức", "Thành viên", "Vai trò trong dự án"],
    [
        ["Quản lý dự án", "Dương Thị Kiều Tiên", "Điều phối kế hoạch, quản lý phạm vi, theo dõi Jira và tổng hợp kết quả Sprint."],
        ["Nhóm phân tích và thiết kế", "Dương Thị Kiều Tiên; Đoàn Thị Ngọc Vân", "Thu thập yêu cầu, thiết kế trải nghiệm người dùng, mô hình dữ liệu và tiêu chí nghiệm thu."],
        ["Nhóm phát triển và kiểm thử", "Đoàn Thị Ngọc Vân; Nguyễn Quốc Việt; Dương Thị Kiều Tiên", "Xây dựng chức năng, tích hợp Firebase/API, kiểm thử, xử lý lỗi và chuẩn bị bản demo."],
    ],
    widths=[1800, 2700, 4300],
)
add_caption(doc, "Bảng 6.2: Cơ cấu tổ chức nhân sự dự án HealWay.")

add_heading(doc, "6.3. Ma trận phân công trách nhiệm RAM", 2)
add_body(
    doc, "Ma trận RAM xác định đầu mối chịu trách nhiệm của các hạng mục chính. Ký hiệu A là chịu trách nhiệm cuối cùng; R là trực tiếp thực hiện; C là tham vấn; I là được thông báo."
)
add_table(
    doc,
    ["Hạng mục công việc", "Kiều Tiên", "Ngọc Vân", "Quốc Việt", "Kết quả cần đạt"],
    [
        ["Lập kế hoạch, quản lý Sprint", "A/R", "C", "I", "Kế hoạch Sprint, backlog và báo cáo tiến độ."],
        ["Phân tích yêu cầu và luồng nghiệp vụ", "A/R", "R", "C", "Yêu cầu được làm rõ và có tiêu chí nghiệm thu."],
        ["Thiết kế UI/UX và dữ liệu", "C", "A/R", "R", "Giao diện và cấu trúc dữ liệu thống nhất."],
        ["Phát triển chức năng Flutter/Dart", "R", "A/R", "R", "Các chức năng triển khai đúng phạm vi Sprint."],
        ["Firebase, API và phân quyền", "C", "R", "A/R", "Dữ liệu, xác thực và API hoạt động ổn định."],
        ["Kiểm thử, sửa lỗi và bàn giao", "A/R", "R", "R", "Test case, bản demo và tài liệu bàn giao hoàn chỉnh."],
    ],
    widths=[2200, 950, 950, 950, 3750],
    centered_columns=(1, 2, 3),
)
add_caption(doc, "Bảng 6.3: Ma trận phân công trách nhiệm RAM.")

add_heading(doc, "6.4. Ma trận kỹ năng của thành viên", 2)
add_body(doc, "Các kỹ năng được đánh giá theo thang điểm 10 để phân công công việc phù hợp với năng lực chủ đạo của từng thành viên.")
add_table(
    doc,
    ["STT", "Họ và tên", "Giao tiếp", "Phân tích", "Flutter/Dart", "UI/UX", "Firebase/CSDL", "API", "Kiểm thử", "Git/GitHub"],
    [
        ["1", "Dương Thị Kiều Tiên", "9", "9", "9", "8", "7", "6", "7", "8"],
        ["2", "Đoàn Thị Ngọc Vân", "8", "7", "7", "9", "9", "7", "9", "8"],
        ["3", "Nguyễn Quốc Việt", "8", "7", "8", "6", "8", "9", "7", "9"],
    ],
    widths=[400, 1600, 600, 600, 800, 550, 950, 500, 700, 900],
    centered_columns=(0, 2, 3, 4, 5, 6, 7, 8, 9),
)
add_caption(doc, "Bảng 6.4: Ma trận kỹ năng của các thành viên dự án HealWay.")

add_heading(doc, "6.5. Gán công việc vào WBS", 2)
add_body(
    doc,
    "Việc phân công bám theo WBS và kế hoạch 7 Sprint. Mỗi hạng mục có một người phụ trách chính, đồng thời "
    "có thành viên phối hợp để giảm phụ thuộc vào cá nhân và bảo đảm có thể kiểm thử chéo."
)
add_table(
    doc,
    ["Giai đoạn", "Công việc trọng tâm", "Phụ trách chính", "Phối hợp"],
    [
        ["Sprint 1", "Khởi tạo dự án, phân tích nghiệp vụ, thiết kế ban đầu.", "Dương Thị Kiều Tiên", "Đoàn Thị Ngọc Vân, Nguyễn Quốc Việt"],
        ["Sprint 2", "Xây dựng dữ liệu, xác thực và phân quyền.", "Nguyễn Quốc Việt", "Dương Thị Kiều Tiên, Đoàn Thị Ngọc Vân"],
        ["Sprint 3", "Phát triển giao diện và chức năng chính cho bệnh nhân.", "Đoàn Thị Ngọc Vân", "Dương Thị Kiều Tiên, Nguyễn Quốc Việt"],
        ["Sprint 4", "Hoàn thiện đặt lịch và các luồng của bệnh nhân.", "Dương Thị Kiều Tiên", "Đoàn Thị Ngọc Vân, Nguyễn Quốc Việt"],
        ["Sprint 5", "Phát triển Doctor Module và kiểm thử tích hợp.", "Nguyễn Quốc Việt", "Dương Thị Kiều Tiên, Đoàn Thị Ngọc Vân"],
        ["Sprint 6", "Hoàn thiện Admin, chatbot AI và tích hợp hệ thống.", "Đoàn Thị Ngọc Vân", "Dương Thị Kiều Tiên, Nguyễn Quốc Việt"],
        ["Sprint 7", "Kiểm thử nghiệm thu, sửa lỗi, hoàn thiện tài liệu và bàn giao.", "Dương Thị Kiều Tiên", "Đoàn Thị Ngọc Vân, Nguyễn Quốc Việt"],
    ],
    widths=[900, 3000, 1800, 3100],
)
add_caption(doc, "Bảng 6.5: Phân công công việc theo WBS và Sprint.")

add_heading(doc, "6.6. Phân bổ nguồn lực và theo dõi tải công việc", 2)
add_body(
    doc,
    "Tải công việc được theo dõi trên Jira theo Sprint, trạng thái và người thực hiện. Nhóm trưởng rà soát backlog, "
    "khối lượng đang thực hiện và các trở ngại trong buổi họp định kỳ để điều chỉnh phân công kịp thời."
)
add_table(
    doc,
    ["Thành viên", "Nguồn lực tập trung", "Cách theo dõi"],
    [
        ["Dương Thị Kiều Tiên", "Quản lý dự án, phân tích nghiệp vụ, phát triển và tổng hợp tài liệu.", "Theo dõi kế hoạch Sprint, tiến độ Jira, rủi ro và kết quả nghiệm thu."],
        ["Đoàn Thị Ngọc Vân", "Thiết kế UI/UX, Firebase/CSDL, phát triển và kiểm thử.", "Theo dõi ticket thiết kế, chức năng giao diện, dữ liệu và test case."],
        ["Nguyễn Quốc Việt", "API, Firebase/CSDL, phát triển chức năng và tích hợp.", "Theo dõi ticket kỹ thuật, pull request, tích hợp và lỗi phát sinh."],
    ],
    widths=[1800, 3100, 3900],
)
add_caption(doc, "Bảng 6.6: Phân bổ nguồn lực và theo dõi tải công việc.")

add_heading(doc, "6.7. Ngân sách nhân sự theo vai trò", 2)
add_body(
    doc,
    "Ngân sách nhân sự được tổng hợp theo vai trò trong kế hoạch chi phí của dự án. Một thành viên có thể đảm nhận nhiều vai trò; "
    "vì vậy bảng dưới đây dùng để quản lý chi phí nhân lực theo nhóm công việc, không phải bảng thu nhập cá nhân."
)
add_table(
    doc,
    ["Vai trò", "Số lượng", "Số ngày", "Đơn giá/ngày (VNĐ)", "Thành tiền (VNĐ)"],
    [
        ["Phân tích yêu cầu", "1", "7", "200.000", "1.400.000"],
        ["Phát triển phần mềm", "2", "67", "200.000", "13.400.000"],
        ["CSDL và kiểm thử", "1", "24", "200.000", "4.800.000"],
        ["Quản lý dự án", "1", "50", "200.000", "10.000.000"],
        ["Tổng cộng", "", "", "", "29.600.000"],
    ],
    widths=[2300, 800, 900, 2000, 2800],
    centered_columns=(1, 2, 3, 4),
)
add_caption(doc, "Bảng 6.7: Ngân sách nhân sự theo vai trò.")

add_heading(doc, "6.8. Báo cáo và điều phối nhân sự", 2)
add_body(
    doc,
    "Nhóm sử dụng Jira để quản lý backlog, phân công ticket, cập nhật trạng thái công việc và theo dõi tiến độ Sprint. "
    "Mã nguồn, pull request và lịch sử thay đổi được quản lý trên GitHub. Trong buổi họp định kỳ, nhóm đánh giá công việc hoàn thành, "
    "công việc còn lại, các trở ngại và thống nhất kế hoạch điều chỉnh cho Sprint tiếp theo."
)
add_table(
    doc,
    ["Báo cáo", "Nội dung", "Tần suất", "Người tổng hợp"],
    [
        ["Cập nhật công việc", "Trạng thái ticket, thời gian thực hiện, trở ngại và nhu cầu hỗ trợ.", "Hằng ngày", "Từng thành viên"],
        ["Báo cáo Sprint", "Kết quả hoàn thành, công việc tồn, lỗi, rủi ro và kế hoạch Sprint kế tiếp.", "Cuối mỗi Sprint", "Dương Thị Kiều Tiên"],
        ["Báo cáo mã nguồn", "Pull request, thay đổi kỹ thuật, kết quả review và lỗi tích hợp.", "Khi phát sinh", "Người thực hiện ticket"],
    ],
    widths=[1600, 3900, 1100, 2200],
)
add_caption(doc, "Bảng 6.8: Báo cáo và điều phối nhân sự dự án.")

add_body(doc, "Tài liệu quản lý nhóm được cập nhật tại Jira và GitHub của dự án HealWay.")

doc.save(OUTPUT)
print(OUTPUT)
