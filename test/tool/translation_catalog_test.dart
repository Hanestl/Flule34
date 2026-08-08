import 'package:flutter_test/flutter_test.dart';

import '../../tool/translation_catalog.dart';

void main() {
  test('CSV 解析支持引号、逗号和换行', () {
    final rows = parseCsv(
      'ID,Name,ChineseName\r\n'
      '1,"tag, one","标签一"\r\n'
      '2,"multi\nline","多行"',
    );

    expect(rows[1], ['1', 'tag, one', '标签一']);
    expect(rows[2], ['2', 'multi\nline', '多行']);
  });

  test('清洗会归一化、去重并删除无效译文', () {
    final result = buildTranslationCatalog('''
ID,Name,ChineseName,VideoCount
1,Foot_Job,足交,10
2,foot job,足交,9
3,same,same,8
4,english,English changed,7
5,ahegao,阿黑颜,6
''');

    expect(result.translations, {'ahegao': '阿黑颜', 'foot job': '足交'});
    expect(result.stats.inputRows, 5);
    expect(result.stats.duplicateRows, 1);
    expect(result.stats.identityRows, 1);
    expect(result.stats.nonChineseRows, 1);
    expect(result.stats.normalizedEnglishRows, 1);
  });

  test('同一英文键出现不同译文时停止生成', () {
    expect(
      () => buildTranslationCatalog('''
ID,Name,ChineseName
1,foot_job,足交
2,foot job,足部服务
'''),
      throwsFormatException,
    );
  });

  test('JSON 输出按英文键稳定排序', () {
    final result = buildTranslationCatalog('''
ID,Name,ChineseName
1,z-tag,最后
2,a-tag,最前
''');

    expect(
      result.toJson().indexOf('a-tag'),
      lessThan(result.toJson().indexOf('z-tag')),
    );
  });
}
