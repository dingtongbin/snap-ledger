# 从主 logo（assets/logo/logo.png，由 test/logo_render_test.dart 程序化生成）
# 派生全部平台图标：
#   - Windows: windows/runner/resources/app_icon.ico（16-256 多尺寸，Runner.rc 引用）
#   - Android: android/app/src/main/res/mipmap-*/ic_launcher.png（5 档密度）
#   - 应用内:  assets/logo/logo_192.png
# 用法：python scripts/gen_icons.py（依赖 Pillow）
from PIL import Image

src = Image.open('assets/logo/logo.png').convert('RGBA')
print('source:', src.size)

# Windows .ico
sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
src.save('windows/runner/resources/app_icon.ico', sizes=sizes)
print('ico written')

# Android 启动图标
mipmaps = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for d, s in mipmaps.items():
    src.resize((s, s), Image.LANCZOS).save(
        f'android/app/src/main/res/{d}/ic_launcher.png')
print('mipmaps written')

# 应用内高清版
src.resize((192, 192), Image.LANCZOS).save('assets/logo/logo_192.png')
print('done')
