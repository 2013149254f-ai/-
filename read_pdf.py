import sys
from pypdf import PdfReader


def read_pdf(file_path: str) -> None:
    reader = PdfReader(file_path)
    total_pages = len(reader.pages)
    print(f"文件: {file_path}")
    print(f"总页数: {total_pages}\n")

    for i, page in enumerate(reader.pages, start=1):
        text = page.extract_text()
        print(f"--- 第 {i} 页 ---")
        print(text)
        print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python3 read_pdf.py <PDF文件路径>")
        sys.exit(1)
    read_pdf(sys.argv[1])
