// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get open => '打开';

  @override
  String get save => '保存';

  @override
  String get saveAs => '另存为';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get minify => '压缩';

  @override
  String get format => '格式化';

  @override
  String get appearance => '外观';

  @override
  String get systemTheme => '跟随系统';

  @override
  String get lightTheme => '浅色';

  @override
  String get darkTheme => '深色';

  @override
  String get glassToolbar => '玻璃工具栏';

  @override
  String get systemLanguage => '跟随系统';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get newTab => '新建标签页';

  @override
  String closeTab(String name) {
    return '关闭 $name';
  }

  @override
  String get untitled => '未命名';

  @override
  String numberedUntitled(int number) {
    return '未命名 $number';
  }

  @override
  String get source => '源码';

  @override
  String get jsonTree => 'JSON 树';

  @override
  String get previousRevision => '上一个有效版本';

  @override
  String get largeFile => '大文件 · 只读';

  @override
  String get emptyDocument => '空白文档';

  @override
  String get checking => '正在校验…';

  @override
  String get validJson => 'JSON 有效';

  @override
  String warningAt(int line, int column, String message) {
    return '第 $line 行第 $column 列警告 · $message';
  }

  @override
  String errorAt(int line, int column, String message) {
    return '第 $line 行第 $column 列错误 · $message';
  }

  @override
  String get treeLargeFile => '大文件模式下停用树视图';

  @override
  String get treeEmpty => '输入有效的 JSON 即可查看树';

  @override
  String get treeLimit => '显示前 10,000 个可见节点';

  @override
  String get rootNode => '根节点';

  @override
  String get collapse => '折叠';

  @override
  String get expand => '展开';

  @override
  String get editNode => '编辑节点';

  @override
  String get nodeActions => '节点操作';

  @override
  String get focusSubtree => '聚焦子树';

  @override
  String get replaceValue => '替换值';

  @override
  String get replaceJsonValue => '替换 JSON 值';

  @override
  String get renameKey => '重命名键';

  @override
  String get goToParent => '返回父节点';

  @override
  String get backToRoot => '返回根节点';

  @override
  String get saveBeforeQuit => '退出前要保存修改吗？';

  @override
  String get saveChanges => '要保存修改吗？';

  @override
  String get cancel => '取消';

  @override
  String get discard => '放弃修改';

  @override
  String get apply => '应用';

  @override
  String openFailed(String detail) {
    return '打开失败 · $detail';
  }

  @override
  String saveFailed(String detail) {
    return '保存失败 · $detail';
  }

  @override
  String get fileAlreadyOpen => '该文件已在另一个标签页中打开。';

  @override
  String get staleNode => '文档已更改，请重新选择节点。';

  @override
  String get quotedString => '请输入带双引号的 JSON 字符串。';

  @override
  String get fileChanged => '磁盘上的文件已更改，请使用「另存为」保留当前修改。';

  @override
  String get fileTooLarge => '无法打开超过 16 MiB 的文件。';

  @override
  String get saveTooLarge => '文档超过 16 MiB 的文件大小限制。';

  @override
  String get filePermissions => '无法保留文件权限。';

  @override
  String get invalidEncoding => '文件编码不是有效的 UTF-8。';

  @override
  String get trailingContent => 'JSON 值后有多余内容。';

  @override
  String get depthLimit => 'JSON 嵌套深度超过 256 层。';

  @override
  String get expectedValue => '此处需要一个 JSON 值。';

  @override
  String get expectedKey => '此处需要带双引号的属性名。';

  @override
  String get duplicateKey => '属性名重复。';

  @override
  String get expectedColon => '属性名后需要冒号。';

  @override
  String get expectedObjectDelimiter => '此处需要逗号或右花括号。';

  @override
  String get expectedArrayDelimiter => '此处需要逗号或右方括号。';

  @override
  String invalidLiteral(String token) {
    return '此处需要 $token。';
  }

  @override
  String get unclosedString => '缺少结束双引号。';

  @override
  String get controlCharacter => '字符串中的控制字符需要转义。';

  @override
  String get invalidUnicodeEscape => 'Unicode 转义前缀后需要四位十六进制数字。';

  @override
  String get invalidEscape => '无效的字符串转义。';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get done => '完成';

  @override
  String get jsonHighlight => 'JSON 高亮';

  @override
  String get highlightMonochrome => '单色';

  @override
  String get highlightAccessibility => '无障碍配色';

  @override
  String get treeStyle => 'JSON 树样式';

  @override
  String get treeStyleClassic => '经典';

  @override
  String get treeStyleColor => '按类型着色';

  @override
  String get treeStyleStriped => '交替行底色';

  @override
  String get treeStyleCompact => '紧凑';

  @override
  String get treeStyleOutline => '线框';

  @override
  String get startup => '启动';

  @override
  String get restoreWorkspace => '启动时恢复上次工作区';

  @override
  String get restoreFailed => '部分文件无法重新打开';

  @override
  String get workspaceSaveFailed => '无法记录下次启动要恢复的工作区。';

  @override
  String get workspacePreferenceFailed => '无法保存启动设置。';

  @override
  String get unsavedChangesDescription => '放弃修改后，未保存的内容将丢失。';

  @override
  String get about => '关于 EJson';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get checkUpdates => '检查版本更新';

  @override
  String get checkingUpdates => '正在检查更新…';

  @override
  String get updateCurrent => '当前已是最新版本。';

  @override
  String updateAvailable(String version) {
    return '发现新版本 $version。';
  }

  @override
  String get noRelease => '暂无正式发布版本。';

  @override
  String get updateFailed => '暂时无法检查更新，请稍后重试。';

  @override
  String get downloadRelease => '查看发布版本';

  @override
  String get buyCoffee => '请我喝杯咖啡';

  @override
  String get browserFailed => '无法打开浏览器。';
}
