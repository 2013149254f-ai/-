import sys
from pathlib import Path
from pypdf import PdfReader


CERTIFICATE_PATH = Path("certificates/中科院2区SSCI 证明.pdf")


def read_ssci_certificate(file_path: Path = CERTIFICATE_PATH) -> None:
    if not file_path.exists():
        print(f"错误: 未找到证明文件 '{file_path}'")
        print("请将 '中科院2区SSCI 证明.pdf' 放置到 certificates/ 目录中。")
        sys.exit(1)

    reader = PdfReader(str(file_path))
    total_pages = len(reader.pages)
    print(f"文件: {file_path}")
    print(f"总页数: {total_pages}\n")

    for i, page in enumerate(reader.pages, start=1):
        text = page.extract_text()
        print(f"--- 第 {i} 页 ---")
        print(text)
        print()


if __name__ == "__main__":
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else CERTIFICATE_PATH
    read_ssci_certificate(path)
