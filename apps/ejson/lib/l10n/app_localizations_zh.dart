// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get compareDocuments => '对比 JSON 文档';

  @override
  String get comparisonBefore => '对比前';

  @override
  String get comparisonAfter => '对比后';

  @override
  String get comparisonSwap => '交换对比两侧';

  @override
  String get comparisonEmpty => '两份文档的结构一致。';

  @override
  String get comparisonLimit => '显示前 1,000 条差异。';

  @override
  String get comparisonFailed => '无法比较这两份文档。';

  @override
  String get comparisonAdded => '新增';

  @override
  String get comparisonRemoved => '删除';

  @override
  String get comparisonChanged => '修改';

  @override
  String get comparisonMissing => '无对应节点';

  @override
  String get goToJsonPath => '跳转到 JSONPath';

  @override
  String get goToNode => '跳转';

  @override
  String get invalidJsonPath => '请输入单节点路径，例如 \$.items[0]。';

  @override
  String get missingJsonPath => '文档中不存在此路径。';

  @override
  String get ambiguousJsonPath => '此路径匹配到重复键。';

  @override
  String get findInDocument => '在文档中查找';

  @override
  String get searchSource => '源码文本';

  @override
  String get searchKeys => '键名';

  @override
  String get searchValues => '值';

  @override
  String get noMatches => '没有匹配项';

  @override
  String get previousMatch => '上一个匹配项';

  @override
  String get nextMatch => '下一个匹配项';

  @override
  String get closeFind => '关闭查找';

  @override
  String get findNeedsValidJson => '按键名或值查找需要有效的 JSON。';

  @override
  String get addProperty => '新增属性';

  @override
  String get addArrayItem => '新增数组项';

  @override
  String get propertyName => '属性名称';

  @override
  String get deleteNode => '删除节点';

  @override
  String get copyJsonPath => '复制 JSONPath';

  @override
  String get jsonPathCopied => '已复制 JSONPath';

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
  String get closeTabMenu => '关闭标签页';

  @override
  String closeTab(String name) {
    return '关闭 $name';
  }

  @override
  String get revealInFolder => '在文件夹中显示';

  @override
  String get revealInFinder => '在 Finder 中显示';

  @override
  String get revealFileMissing => '文件已不存在，已打开原所在文件夹。';

  @override
  String get revealFolderMissing => '找不到文件所在的文件夹。';

  @override
  String get revealFolderFailed => '无法打开文件管理器。';

  @override
  String get copyFilePath => '复制文件路径';

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
  String get sourcePreviousPage => '上一页源码';

  @override
  String get sourceNextPage => '下一页源码';

  @override
  String get sourceGoToPage => '跳转到源码页';

  @override
  String sourcePage(int page, int total) {
    return '第 $page 页，共 $total 页';
  }

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
  String get restoreFailedDescription =>
      '这些文件属于上次打开的工作区。文件可能已移动、访问权限发生变化，或当前无法读取。';

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

  @override
  String get replaceText => '替换为';

  @override
  String get replace => '替换';

  @override
  String get replaceCurrent => '替换当前';

  @override
  String get replaceAll => '全部替换';

  @override
  String get matchCase => '区分大小写';

  @override
  String get useRegex => '正则表达式';

  @override
  String get invalidRegex => '正则表达式无效';

  @override
  String get escapeJson => '转义为 JSON 字符串';

  @override
  String get unescapeJson => '反转义 JSON 字符串';

  @override
  String get unescapeFailed => '请输入带双引号的有效 JSON 字符串。';

  @override
  String get extractSubtree => '提取到新标签页';

  @override
  String get arrayTable => '数组表格';

  @override
  String get copyNodeValue => '复制 JSON 值';

  @override
  String get copyDecodedString => '复制字符串内容';

  @override
  String get valueCopied => '已复制节点值';

  @override
  String get filterRows => '筛选行';

  @override
  String get emptyArray => '数组为空';

  @override
  String get exportCsv => '导出 CSV';

  @override
  String get csvExported => '已导出 CSV';

  @override
  String get exportFailed => '导出失败';

  @override
  String get tableInstructions => '点击列标题排序，点击单元格复制内容。导出使用当前筛选和排序结果。';

  @override
  String tableRowCount(int visible, int total) {
    return '$visible / $total 行';
  }

  @override
  String nodeCount(int count) {
    return '$count 个节点';
  }

  @override
  String documentBytes(int bytes) {
    return '$bytes 字节';
  }

  @override
  String documentStatistics(int bytes, int nodes, int depth, int arrayLength) {
    return '$bytes 字节 · $nodes 个节点 · 最大深度 $depth（根节点为 0）· 最长数组 $arrayLength 项';
  }

  @override
  String get jsonQuery => 'JSONPath 查询';

  @override
  String get runQuery => '查询';

  @override
  String get queryRunning => '正在查询…';

  @override
  String get jsonQueryFailed => '查询失败，请重试。';

  @override
  String invalidJsonQuery(int position) {
    return '第 $position 个字符附近的 JSONPath 语法无效或暂不支持。';
  }

  @override
  String get jsonQueryHelp =>
      '支持字段、数组下标、* 通配符和 [?条件]。条件支持 @ 相对路径、存在判断、标量比较、&&、|| 和 !。点击结果定位源码。';

  @override
  String queryResultCount(int count) {
    return '$count 条结果';
  }

  @override
  String get extractQueryResults => '提取结果到新标签页';

  @override
  String get goToSource => '定位源码';

  @override
  String get captureReplacementHelp => '\$1、\$2 引用捕获组，\$\$ 插入美元符号。';

  @override
  String get formatIndentation => '格式化缩进';

  @override
  String get indentTwo => '2 个空格';

  @override
  String get indentFour => '4 个空格';

  @override
  String get indentEight => '8 个空格';

  @override
  String get indentTabs => '制表符';

  @override
  String get lineEnding => '换行符';

  @override
  String get preserveLineEnding => '保留原样';

  @override
  String get toolPreferenceFailed => '无法保存设置，请重试。';

  @override
  String get saveQuery => '收藏查询';

  @override
  String get unsaveQuery => '取消收藏';

  @override
  String get savedQueries => '收藏的查询';

  @override
  String get noSavedQueries => '暂无收藏的查询';

  @override
  String get moveArrayItemUp => '上移数组项';

  @override
  String get moveArrayItemDown => '下移数组项';

  @override
  String get duplicateArrayItem => '复制数组项';

  @override
  String get sortArray => '排序数组';

  @override
  String get sortField => '排序依据';

  @override
  String get sortValue => '元素值';

  @override
  String get sortAscending => '升序';

  @override
  String get sortDescending => '降序';

  @override
  String get sortArrayHelp => '缺失字段的元素排在末尾，相等的值保留原顺序。';

  @override
  String get sortArrayAmbiguous => '排序字段存在重复键，请选择其他字段。';

  @override
  String get readingDisplay => '阅读显示';

  @override
  String get readingFont => '阅读字体';

  @override
  String get fontSize => '字号';

  @override
  String get decreaseFontSize => '减小字号';

  @override
  String get increaseFontSize => '增大字号';

  @override
  String get lineSpacing => '行距';

  @override
  String get spacingCompact => '紧凑';

  @override
  String get spacingStandard => '标准';

  @override
  String get spacingSpacious => '宽松';

  @override
  String get readingPreview => '预览';

  @override
  String get resetReading => '恢复默认';

  @override
  String get defaultReadingFont => '系统默认等宽字体';

  @override
  String get searchFonts => '搜索本机字体';

  @override
  String get refreshFonts => '刷新字体列表';

  @override
  String get monospaceFont => '等宽字体';

  @override
  String get fontListFailed => '无法读取字体列表，点击重试。';

  @override
  String get noMatchingFonts => '没有匹配的字体';

  @override
  String fontUnavailable(String name) {
    return '字体「$name」暂不可用，当前使用默认字体。';
  }

  @override
  String get recentFiles => '最近文件';

  @override
  String get searchRecentFiles => '搜索文件名或路径';

  @override
  String get noRecentFiles => '暂无最近文件';

  @override
  String get removeRecentFile => '从最近列表移除';

  @override
  String get clearRecentFiles => '清空最近列表';

  @override
  String get recentSaveFailed => '文件已打开或保存，但无法记录最近文件。';

  @override
  String get commandPalette => '命令面板';

  @override
  String get searchCommands => '搜索命令…';

  @override
  String get noMatchingCommands => '没有匹配的命令';

  @override
  String get commandKeyboardHelp => '↑↓ 选择  ·  Enter 执行  ·  Esc 关闭';

  @override
  String get dropFilesToOpen => '松开以打开文件';

  @override
  String get noDroppedFiles => '拖入内容中没有可打开的本地文件。';

  @override
  String get droppedCopyOpened => '已将拖入的临时副本作为新文档打开。';

  @override
  String get someFilesFailed => '部分文件无法打开';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsFormatting => '格式化';

  @override
  String get website => '官方网站';

  @override
  String get schemaValidation => 'JSON Schema 校验';

  @override
  String get schemaHelp => '粘贴或载入本地 Schema，点击校验结果定位节点。支持内嵌引用。';

  @override
  String get loadSchema => '载入 Schema';

  @override
  String get validateSchema => '校验';

  @override
  String get schemaChecking => '处理中…';

  @override
  String get schemaFailed => '校验失败';

  @override
  String get schemaValid => '符合 Schema';

  @override
  String get redactData => '数据脱敏';

  @override
  String get redactHelp =>
      '字段名不区分大小写，以逗号或换行分隔。匹配值会替换为指定字符串。JSONPath 每行一条，支持通配符。';

  @override
  String get redactKeys => '字段名';

  @override
  String get redactPaths => 'JSONPath（可选）';

  @override
  String get redactReplacement => '替换字符串';

  @override
  String get openRedactedCopy => '打开脱敏副本';

  @override
  String get saveRedactedCopy => '保存脱敏副本';

  @override
  String get documentTools => '文档工具';

  @override
  String schemaIssues(int count) {
    return '$count 个校验问题';
  }

  @override
  String redactCount(int count) {
    return '已替换 $count 处';
  }

  @override
  String get comparisonSelectAll => '选择或取消全部已显示差异';

  @override
  String comparisonSelected(int count) {
    return '已选 $count 项';
  }

  @override
  String get comparisonPreviewChanges => '预览应用到左侧';

  @override
  String get comparisonApplyChanges => '应用差异';

  @override
  String get comparisonApplyPreview => '应用差异预览';

  @override
  String comparisonApplyTarget(String name) {
    return '目标文档 · $name';
  }

  @override
  String get comparisonApplyDirection => '右侧 → 左侧 · 交换两侧可反向应用';

  @override
  String get comparisonStale => '文档已变化，请重新比较。';

  @override
  String get comparisonRefresh => '重新比较';

  @override
  String get comparisonApplyFailed => '无法生成应用预览，请重新比较后重试。';

  @override
  String get formatConversion => '格式转换';

  @override
  String get conversionDirection => '转换方向';

  @override
  String get conversionInput => '源内容';

  @override
  String get conversionDocument => 'YAML 文档序号（从 1 起）';

  @override
  String get conversionDocumentError => '请输入从 1 开始的文档序号。';

  @override
  String get conversionYamlNotice =>
      'JSON 中保留数据与精确数字。YAML 注释会移除，锚点、别名和合并键会展开；无法表示的类型会提示错误。';

  @override
  String get conversionCsvNotice =>
      'CSV 支持对象或数组。对象字段按列输出，数组中的其他元素写入 \$ 值列。值写为文本，嵌套结构默认写为 JSON 字符串；缺失字段和空字符串均为空单元格，null 写为 null。预览后可选择并调整列顺序。';

  @override
  String get conversionDelimiter => '分隔符';

  @override
  String get conversionComma => '逗号';

  @override
  String get conversionSemicolon => '分号';

  @override
  String get conversionHeader => '包含表头';

  @override
  String get conversionFlatten => '将嵌套结构展开为 JSONPath 列';

  @override
  String get conversionColumns => '导出列与顺序';

  @override
  String get conversionCancel => '取消转换';

  @override
  String get conversionRun => '转换并预览';

  @override
  String get conversionCopy => '复制结果';

  @override
  String get conversionCopied => '已复制转换结果';

  @override
  String get conversionOpen => '在新标签页打开';

  @override
  String get conversionExport => '导出文件';

  @override
  String contentValid(String format) {
    return '$format 格式有效';
  }

  @override
  String conversionDocuments(int count) {
    return '$count 份 YAML 文档';
  }

  @override
  String get conversionColumnUp => '上移列';

  @override
  String get conversionColumnDown => '下移列';

  @override
  String get showReplace => '展开替换';

  @override
  String get hideReplace => '收起替换';

  @override
  String get treeStyleStructure => '结构导航';

  @override
  String get treeStyleGuides => '层级引导线';

  @override
  String get highlightPreview => '高亮预览';

  @override
  String get treePreview => '树样式预览';

  @override
  String formatFailed(String error) {
    return '格式化失败：$error';
  }

  @override
  String get conversionCsvPath => '源数据 JSONPath';

  @override
  String get conversionTomlNotice =>
      'TOML 1.0。转为 TOML 要求根节点为对象、键名唯一、无 null，整数在有符号 64 位范围内且浮点数可精确表达。日期时间转为 JSON 字符串，转换时省略注释。';

  @override
  String get conversionXmlNotice =>
      '类型映射使用 ejson 命名空间保留 JSON 类型、数字原文和键名。元素映射要求单个根属性，支持 @attributes、#text 和 #content。';

  @override
  String get conversionXmlImportNotice =>
      '类型 XML 还原 JSON 类型。普通 XML 使用 @attributes、#text 和有序 #content，文本保持字符串；转换时省略注释与处理指令。';

  @override
  String get xmlMapping => 'XML 映射方式';

  @override
  String get xmlTypedMapping => 'JSON 类型映射';

  @override
  String get xmlElementMapping => '元素映射';

  @override
  String get xmlRootName => '根元素名称';

  @override
  String get csvImportNotice => '单元格默认保持文本并保留前导零。可指定列名与类型，空单元格处理规则作用于所有列。';

  @override
  String get csvHeaderRow => '首行为列名';

  @override
  String get csvEmptyCells => '空单元格';

  @override
  String get csvEmptyString => '空字符串';

  @override
  String get csvOmitField => '省略字段';

  @override
  String get csvImportColumns => '列名与类型';

  @override
  String get csvColumnName => '列名';

  @override
  String get csvColumnType => '列类型';

  @override
  String get csvTypeText => '文本';

  @override
  String get csvTypeNumber => '数字';

  @override
  String get csvTypeBoolean => '布尔值';

  @override
  String get documentStructure => '结构';

  @override
  String csvVisibleColumns(int visible, int total) {
    return '显示 $visible / $total 列';
  }

  @override
  String get csvTableHeader => '表头行';

  @override
  String get noStructure => '暂无可显示的结构';

  @override
  String newDocument(String format) {
    return '新建 $format 文档';
  }

  @override
  String get newDocumentFormat => '新建文档格式';

  @override
  String get saveAsFormat => '文件类型';

  @override
  String get saveAsConversionHint =>
      '转换使用默认设置，请检查预览后保存。CSV 列设置、YAML 文档选择及 XML 映射可通过「格式转换」调整。';

  @override
  String saveAsExtensionError(String extension) {
    return '所选文件类型需要使用 .$extension 扩展名。';
  }

  @override
  String saveAsOverwrite(String path) {
    return '文件已存在，是否覆盖？\n$path';
  }

  @override
  String get autosaveDrafts => '自动保存恢复草稿';

  @override
  String get autosaveDescription =>
      '停止编辑 2 秒后保存恢复草稿，持续编辑时最多间隔 10 秒保存。异常退出后，下次启动会恢复草稿。';

  @override
  String get autosaveDisabled => '恢复草稿自动保存已关闭';

  @override
  String get autosaveWaiting => '等待保存恢复草稿';

  @override
  String get autosaveSaving => '正在保存恢复草稿';

  @override
  String get autosaveSaved => '恢复草稿已保存';

  @override
  String get autosaveFailed => '恢复草稿保存失败，点击重试。';

  @override
  String recoveryRestored(int count) {
    return '已恢复 $count 个文档的未保存修改。';
  }

  @override
  String get autosaveUnavailable => '恢复草稿存储初始化失败，自动保存暂不可用。';

  @override
  String get diskSyncSetting => '磁盘文件双向同步';

  @override
  String get diskSyncDescription =>
      '停止输入 500 毫秒后将修改写入已命名文件，包括语法未完成的内容。每秒检查外部修改，发生冲突时暂停同步。';

  @override
  String get diskSyncWaiting => '等待写入磁盘';

  @override
  String get diskSyncSaving => '正在写入磁盘';

  @override
  String get diskSyncSaved => '已保存到磁盘';

  @override
  String get diskSyncFailed => '磁盘同步失败';

  @override
  String get diskSyncConflict => '文件同步冲突';

  @override
  String get diskSyncConflictDescription =>
      '磁盘文件已被外部修改，当前也有本地编辑。同步已暂停，请选择保留的版本。';

  @override
  String diskSyncError(String error) {
    return '文件同步已暂停。$error';
  }

  @override
  String get diskSyncCompare => '对照查看';

  @override
  String get diskSyncLocal => '当前编辑内容';

  @override
  String get diskSyncDisk => '磁盘版本';

  @override
  String get diskSyncReload => '加载磁盘版本';

  @override
  String get diskSyncOverwrite => '保留本地修改';

  @override
  String get diskSyncRetry => '重试';

  @override
  String get diskSyncReloadConfirm => '加载最新磁盘版本并放弃当前本地修改？';

  @override
  String get diskSyncOverwriteConfirm => '将当前本地修改写入并覆盖磁盘版本？如果磁盘版本再次变化，需要重新确认。';

  @override
  String get repairJson => '修复 JSON';

  @override
  String get repairAlreadyValid => '当前文档已经是有效的 JSON。';

  @override
  String get repairFailed => '无法完成修复，请补全缺失的值或消除含义不明确的语法后重试。';

  @override
  String get repairBom => '已移除 BOM 标记';

  @override
  String get repairComments => '已移除注释';

  @override
  String get repairSingleQuotes => '已转换单引号字符串';

  @override
  String get repairUnquotedKeys => '已为属性名添加引号';

  @override
  String get repairTrailingCommas => '已移除尾逗号';

  @override
  String get repairMissingCommas => '已补充逗号';

  @override
  String get repairMissingColons => '已补充冒号';

  @override
  String get repairClosingContainers => '已闭合对象和数组';

  @override
  String get repairClosingStrings => '已闭合字符串';

  @override
  String get repairControlCharacters => '已转义控制字符';

  @override
  String get repairLiterals => '已规范化字面量';

  @override
  String get jsonLinesRecords => '记录';

  @override
  String get jsonLinesSearch => '搜索记录';

  @override
  String get jsonLinesFilter => '显示记录';

  @override
  String get jsonLinesAll => '全部记录';

  @override
  String get jsonLinesValid => '有效记录';

  @override
  String get jsonLinesInvalid => '无效记录';

  @override
  String get jsonLinesNoMatches => '没有匹配的记录';

  @override
  String get jsonLinesBlank => '空白行';

  @override
  String get jsonLinesExport => '导出筛选结果';

  @override
  String get jsonLinesExported => '筛选结果已导出';

  @override
  String jsonLinesCount(int shown, int total, int invalid) {
    return '$shown / $total 条记录 · $invalid 条无效';
  }

  @override
  String get jsonLinesConversionNotice =>
      '每行包含一个 JSON 值，空白行会标记为无效。JSON Lines 转换为 JSON 数组，JSON 数组按元素逐行导出，其他 JSON 值导出为一条记录。';

  @override
  String get sourceFolding => '源码折叠';

  @override
  String get treeConnectors => '树状层级虚线';
}
