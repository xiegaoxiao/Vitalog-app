# 素材

## 食材插画

`assets/food/*.svg`：OpenMoji 17.0.0，HfG Schwäbisch Gmünd 与贡献者，CC BY-SA 4.0，原样使用。来源为官方项目 npm 发布包： https://github.com/hfg-gmuend/openmoji 。完整许可在 `assets/licenses/OpenMoji-CC-BY-SA-4.0.txt`，应用「素材与指标说明」内也有署名和许可。

内置土豆、红薯、番茄、黄瓜、胡萝卜、西兰花、青菜、苹果、香蕉、桃、橙、玉米、鸡蛋、鸡肉、牛奶、面包。其他食材目前使用青菜插画作为通用图；所有图片仅作图示。

## 饮食配图

`assets/images/meal-hero.png` 使用内置 ImageGen 工具生成。图片已复制到项目，应用不依赖默认生成目录。它是通用配图，并非每道菜的成品图。

最终提示词：

> Use case: photorealistic-natural. Asset type: recipe card hero photograph for a Chinese personal wellness Android app. Primary request: a beautiful overhead photograph of a simple cooked meal in a pale ceramic bowl: sliced chicken breast, boiled potato cubes, bright green leafy vegetables, tomato pieces. This is a practical one-pot student meal, no fancy garnishes. Scene/backdrop: bold cobalt blue tabletop, a small vivid orange cloth and lime-green accent at the edge; tasteful color blocking. Composition: landscape 3:2, food bowl fills central-right area, recognizable appetizing ingredients, usable uncluttered negative space on the left. Lighting: clean natural daylight, realistic soft shadows. Constraints: no lettering, no UI, no numbers, no logos, no watermark, no hands. Intended for an in-app illustration only; do not imply nutritional quantities or health claims.

## 字体与图标

`assets/fonts/NotoSansSC.ttf`：Google Fonts 官方 Noto Sans SC，SIL Open Font License，许可在 `assets/licenses/NotoSansSC-OFL.txt`。随应用内置，离线可显示中文。

应用图标是项目自身的安卓 VectorDrawable 与 SVG；导航图标使用 Flutter Material Icons / Cupertino Icons。

## 卡通版视觉更新

根据用户参考图更新为粉色、奶白、粗黑描边和圆润卡通风格。以下素材由内置 ImageGen 工具生成，已复制进项目，离线可用。

- `assets/images/vitalog-buddy.png`：透明背景抱心小伙伴，用于首页、品牌头像、身体档案和空状态。
- `assets/images/meal-cartoon.png`：同风格通用饮食插画，替换界面中的写实配图；原配图保留但不再展示。
- `android/app/src/main/res/drawable/ic_launcher_vitalog.xml` 与 `web/favicon.svg`：代码绘制的小熊头像图标。

小伙伴最终提示词：

> Use case: illustration-story. Asset type: transparent mascot sticker for the Chinese wellness app Vitalog. Reference image is style guidance only: thick slightly wobbly near-black outlines, simple flat fills, round white animal, pink blush and sparkly eyes. Create an original plump cream-white little bear-like dumpling buddy, tiny round ears, short paws, rosy pink oval cheeks, expressive friendly eyes and small smile, holding a small pink heart with both paws. Full body centered, large character, square composition, generous transparent margin. Flat hand-drawn kawaii cartoon, bold rounded black lines, no shading gradients, no realism, no lettering, no watermark. Background must be truly transparent. Preserve style feeling but make this an original character, not a reproduction.

饮食插画最终提示词：

> Use case: illustration-story. Asset type: wide recipe-card hero illustration for a cute personal health app. Style guidance is the supplied reference: thick slightly wobbly near-black outlines, soft white shapes, pink blush, simple flat hand-drawn Japanese kawaii cartoon. Draw a smiling cream-colored round soup bowl, filled with recognizable potato cubes, chicken slices, tomato pieces and green leafy vegetables, little steam squiggles, surrounded by a few tiny pink hearts and yellow sparkles. Landscape 3:2 framing, bowl centered with ample breathing room, pale peach-pink solid background, cheerful flat colors, smooth rounded friendly shapes. Original illustration, no reference character, no photography, no 3D, no gradients, no words, no nutrition numbers, no watermark. This is a generic food illustration, not an exact dish photograph.
