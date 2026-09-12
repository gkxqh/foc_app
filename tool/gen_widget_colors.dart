import 'dart:io';

/// 小组件色板单一生成源：状态色与 lib/core/theme/app_theme.dart 同源。
/// 改色值时同步修改（App 侧改 app_theme.dart，这里同步镜像），然后运行：
///   dart run tool/gen_widget_colors.dart
/// 重新生成 values/ 与 values-night/ 两份 widget_colors.xml，
/// XML 不再手工维护，避免「App - 浅色 XML - 深色 XML」三处漂移。
void main() {
  const resDir = 'android/app/src/main/res';

  // 通用色：(名称, 浅色, 深色)
  const palette = <(String, String, String)>[
    ('widget_bg', '#FFFFFF', '#1B1C1E'),
    ('widget_text_primary', '#1C1B1F', '#E7E9EE'),
    ('widget_text_secondary', '#60646B', '#A8AEB8'),
    ('widget_text_tertiary', '#9AA0A8', '#6E747E'),
    ('widget_accent', '#4187F2', '#4187F2'),
    ('widget_button_ghost', '#F0F2F5', '#2A2C30'),
  ];

  // 状态色：与 AppTheme.getStatusColor 同源（2026-09-11 校准版）。
  // 深色版仅提亮 confirming：#B8860B 深金在深底上对比度不足，其余两版一致。
  const status = <(String, String, String)>[
    ('widget_status_pending', '#4187F2', '#4187F2'),
    ('widget_status_repairing', '#F27F41', '#F27F41'),
    ('widget_status_confirming', '#B8860B', '#D4A017'),
    ('widget_status_done', '#57BE6A', '#57BE6A'),
    ('widget_status_closed', '#DA3231', '#DA3231'),
    ('widget_status_canceled', '#9E9E9E', '#9E9E9E'),
  ];

  String render(String header, List<(String, String, String)> entries) {
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln('<!-- $header（由 tool/gen_widget_colors.dart 生成，勿手工修改） -->')
      ..writeln('<resources>');
    for (final (name, light, _) in entries) {
      buf.writeln('    <color name="$name">$light</color>');
    }
    buf
      ..writeln('</resources>')
      ..writeln();
    return buf.toString();
  }

  String renderNight(List<(String, String, String)> entries) {
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln(
        '<!-- 深色模式色板（由 tool/gen_widget_colors.dart 生成，勿手工修改）；'
        '小组件只能跟随系统深浅，无法读取 App 内深色设置 -->',
      )
      ..writeln('<resources>');
    for (final (name, _, dark) in entries) {
      buf.writeln('    <color name="$name">$dark</color>');
    }
    buf
      ..writeln('</resources>')
      ..writeln();
    return buf.toString();
  }

  final all = [...palette, ...status];
  final files = <(String, String)>[
    (
      '$resDir/values/widget_colors.xml',
      render('小组件色板：状态色与 lib/core/theme/app_theme.dart 同源', all),
    ),
    ('$resDir/values-night/widget_colors.xml', renderNight(all)),
  ];

  for (final (path, content) in files) {
    File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    stdout.writeln('$path written');
  }
}
