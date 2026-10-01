# Noto Sans KR 원본 OTF(notofonts/noto-cjk Sans/SubsetOTF/KR)를 앱 번들용으로 서브셋한다.
# fonttools 필요: python3 -m venv .venv && .venv/bin/pip install fonttools
# 사용: .venv/bin/python scripts/fonts/subset_fonts.py <원본 OTF 폴더>
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
FONTS_DIR = REPO_ROOT / 'EcoGuard' / 'Resources' / 'Fonts'
WEIGHTS = ['Regular', 'Medium', 'Bold']

# 흔한 문장부호·기호. Figma 문구에 새 기호가 쓰이면 여기에 추가한다.
PUNCTUATION = (
    ' ·×÷°±©®'
    '‐–—‘’“”•…‰※‹›'
    '₩€'
    '←↑→↓'
    '○●□■△▲▽▼◆◇★☆'
    '、。〈〉《》「」『』【】〜'
)


def subset_text():
    # Python euc_kr은 완성형 밖 글자도 8바이트 조합 시퀀스로 인코딩하므로 2바이트만 KS X 1001 완성형이다.
    hangul = [chr(c) for c in range(0xAC00, 0xD7A4) if len(chr(c).encode('euc_kr')) == 2]
    assert len(hangul) == 2350, len(hangul)
    jamo = [chr(c) for c in range(0x3131, 0x318F)]
    latin = [chr(c) for c in range(0x20, 0x7F)]
    return ''.join(hangul + jamo + latin + list(PUNCTUATION))


def main():
    if len(sys.argv) != 2:
        sys.exit('사용: subset_fonts.py <원본 OTF 폴더>')
    source_dir = pathlib.Path(sys.argv[1])
    text = subset_text()

    options = subset.Options()
    options.layout_features = ['*']
    options.name_IDs = ['*']
    options.name_languages = ['*']
    options.name_legacy = True
    options.notdef_outline = True
    options.hinting = True
    options.legacy_kern = True

    for weight in WEIGHTS:
        name = f'NotoSansKR-{weight}.otf'
        font = TTFont(source_dir / name)
        absent = [f'U+{ord(c):04X}' for c in text if ord(c) not in font.getBestCmap()]
        if absent:
            print(f'{name}: 원본에 없는 글자 {absent}')
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
        font.save(FONTS_DIR / name)
        print(f'{name}: {len(text)}자, {(FONTS_DIR / name).stat().st_size:,} bytes')


if __name__ == '__main__':
    main()
