# 앱 Swift 문자열 리터럴의 글자가 번들 Noto Sans KR 서브셋에 모두 있는지 검사한다. 누락이 있으면 exit 1.
# fonttools 필요: python3 -m pip install fonttools (또는 venv에 설치 후 그 python으로 실행)
# 누락 글자는 scripts/fonts/subset_fonts.py의 PUNCTUATION에 추가하고 원본에서 다시 서브셋한다.
import pathlib
import re
import sys

try:
    from fontTools.ttLib import TTFont
except ImportError:
    sys.exit('fonttools가 필요합니다: python3 -m pip install fonttools')

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO_ROOT / 'EcoGuard'
FONTS_DIR = SOURCE_DIR / 'Resources' / 'Fonts'
WEIGHTS = ['Regular', 'Medium', 'Bold']


def string_literals(source):
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    literals = re.findall(r'"""(.*?)"""', source, flags=re.S)
    source = re.sub(r'""".*?"""', '', source, flags=re.S)
    for line in source.splitlines():
        code, in_string, i = '', False, 0
        while i < len(line):
            if in_string and line[i] == '\\':
                code += line[i:i + 2]
                i += 2
                continue
            if line[i] == '"':
                in_string = not in_string
            if not in_string and line.startswith('//', i):
                break
            code += line[i]
            i += 1
        literals += re.findall(r'"((?:[^"\\]|\\.)*)"', code)
    return literals


def main():
    used = {}
    for path in sorted(SOURCE_DIR.rglob('*.swift')):
        for literal in string_literals(path.read_text(encoding='utf-8')):
            for char in literal:
                if ord(char) > 0x7E:
                    used.setdefault(char, set()).add(path.relative_to(REPO_ROOT).as_posix())

    has_missing = False
    for weight in WEIGHTS:
        name = f'NotoSansKR-{weight}.otf'
        cmap = TTFont(FONTS_DIR / name).getBestCmap()
        missing = sorted(char for char in used if ord(char) not in cmap)
        for char in missing:
            print(f'{name}: 누락 {char!r} U+{ord(char):04X} ({", ".join(sorted(used[char]))})')
        has_missing = has_missing or bool(missing)

    print(f'검사한 글자 {len(used)}개, 누락 {"있음" if has_missing else "0개"}')
    sys.exit(1 if has_missing else 0)


if __name__ == '__main__':
    main()
