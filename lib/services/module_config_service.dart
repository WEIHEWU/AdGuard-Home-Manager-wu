import 'dart:convert';
import 'dart:io';

class ModuleConfigService {
  static const String moduleConfigPath = '/data/adb/agh/scripts/config.prop';
  static const String moduleYamlPath = '/data/adb/agh/bin/AdGuardHome.yaml';

  bool get _isAndroid => Platform.isAndroid;

  Future<bool> hasRoot() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run('su', ['-c', 'id']);
      return result.stdout.toString().contains('uid=0');
    } catch (_) {
      return false;
    }
  }

  Future<String?> readAdGuardYaml() async {
    if (!_isAndroid) return null;
    try {
      final result = await Process.run('su', ['-c', 'cat $moduleYamlPath']);
      if (result.exitCode != 0) {
        return null;
      }
      return result.stdout.toString();
    } catch (_) {
      return null;
    }
  }

  String? parseHttpAddress(String yamlText) {
    final lines = yamlText.split('\n');
    var inHttp = false;
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('http:')) {
        inHttp = true;
        continue;
      }
      if (inHttp) {
        if (trimmed.isNotEmpty && !line.startsWith(' ')) {
          inHttp = false;
        }
        if (trimmed.startsWith('address:')) {
          final value = trimmed.substring('address:'.length).trim();
          return value.replaceAll('"', '').replaceAll("'", '');
        }
      }
    }
    return null;
  }

  Future<String?> readHttpAddress() async {
    final yaml = await readAdGuardYaml();
    if (yaml == null) return null;
    return parseHttpAddress(yaml);
  }

  Future<String> readProxyUrl() async {
    if (!_isAndroid) return '';
    try {
      final result = await Process.run('su', ['-c', 'cat $moduleConfigPath']);
      if (result.exitCode != 0) {
        return '';
      }
      final content = result.stdout.toString();
      final line = content.split('\n').firstWhere(
            (line) => line.trimLeft().startsWith('PROXY_URL='),
            orElse: () => '',
          );
      if (line.isEmpty) return '';
      // 模块配置默认写入 PROXY_URL=" "（引号内一个空格）作为占位，
      // 去掉引号后再 trim，空白值统一按“未设置”处理，不显示到输入框。
      return line
          .substring(line.indexOf('PROXY_URL=') + 'PROXY_URL='.length)
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim();
    } catch (_) {
      return '';
    }
  }

  Future<bool> saveProxyUrl(String proxyUrl) async {
    if (!_isAndroid) return false;
    try {
      final readResult =
          await Process.run('su', ['-c', 'cat $moduleConfigPath']);
      if (readResult.exitCode != 0) return false;

      final value = proxyUrl.trim();
      final lines = readResult.stdout.toString().split('\n');
      final updatedLines = <String>[];
      var replaced = false;

      for (final line in lines) {
        if (line.trimLeft().startsWith('PROXY_URL=')) {
          replaced = true;
          // 空值时保留模块原有的空格占位，避免变量缺失导致模块脚本报错。
          updatedLines
              .add(value.isNotEmpty ? 'PROXY_URL="$value"' : 'PROXY_URL=" "');
          continue;
        }
        updatedLines.add(line);
      }
      if (!replaced) {
        updatedLines
            .add(value.isNotEmpty ? 'PROXY_URL="$value"' : 'PROXY_URL=" "');
      }
      final content = updatedLines.join('\n');

      final writer =
          await Process.start('su', ['-c', 'cat > $moduleConfigPath']);
      writer.stdin.add(utf8.encode(content));
      await writer.stdin.close();
      final writeResult = await writer.exitCode;
      if (writeResult == 0) {
        Process.run('su', ['-c', 'sh /data/adb/agh/scripts/ProxyConfig.sh --once >/dev/null 2>&1 &']);
      }
      return writeResult == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> readVpnDnsTakeover() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run('su', ['-c', 'cat $moduleConfigPath']);
      if (result.exitCode != 0) return false;
      final content = result.stdout.toString();
      for (final rawLine in content.split('\n')) {
        final line = rawLine.trim();
        if (line.startsWith('VPN_DNS_TAKEOVER=')) {
          final val = line
              .substring('VPN_DNS_TAKEOVER='.length)
              .replaceAll('"', '')
              .replaceAll("'", '')
              .trim();
          return val == '1';
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveVpnDnsTakeover(bool enabled) async {
    if (!_isAndroid) return false;
    try {
      final readResult =
          await Process.run('su', ['-c', 'cat $moduleConfigPath']);
      if (readResult.exitCode != 0) return false;

      final targetVal = enabled ? '1' : '0';
      final lines = readResult.stdout.toString().split('\n');
      final updatedLines = <String>[];
      var replaced = false;

      for (final line in lines) {
        if (line.trimLeft().startsWith('VPN_DNS_TAKEOVER=')) {
          replaced = true;
          updatedLines.add('VPN_DNS_TAKEOVER=$targetVal');
          continue;
        }
        updatedLines.add(line);
      }
      if (!replaced) {
        updatedLines.add('VPN_DNS_TAKEOVER=$targetVal');
      }
      final content = updatedLines.join('\n');

      final writer =
          await Process.start('su', ['-c', 'cat > $moduleConfigPath']);
      writer.stdin.add(utf8.encode(content));
      await writer.stdin.close();
      final writeResult = await writer.exitCode;
      if (writeResult == 0) {
        await reloadFirewallRules();
      }
      return writeResult == 0;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getModuleDiagnostics() async {
    if (!_isAndroid) {
      return {
        'running': false,
        'pid': '',
        'dnsPort': '',
        'natOk': false,
        'sniOk': false,
      };
    }
    try {
      const cmd = '''
pid=\$(pidof AdGuardHome 2>/dev/null | awk '{print \$1}')
dns_port=\$(sed -n 's/^redir_port=//p' /data/adb/agh/scripts/config.prop 2>/dev/null | head -n 1)
iptables -w 2 -t nat -C OUTPUT -j ADGUARD >/dev/null 2>&1 && nat_ok=1 || nat_ok=0
iptables -w 2 -t filter -C OUTPUT -j AGH_SNI >/dev/null 2>&1 && sni_ok=1 || sni_ok=0
echo "PID=\$pid"
echo "PORT=\$dns_port"
echo "NAT=\$nat_ok"
echo "SNI=\$sni_ok"
''';
      final result = await Process.run('su', ['-c', cmd]);
      if (result.exitCode != 0) {
        return {
          'running': false,
          'pid': '',
          'dnsPort': '',
          'natOk': false,
          'sniOk': false,
        };
      }
      String pid = '';
      String dnsPort = '';
      bool natOk = false;
      bool sniOk = false;
      for (final line in result.stdout.toString().split('\n')) {
        final t = line.trim();
        if (t.startsWith('PID=')) pid = t.substring(4).trim();
        if (t.startsWith('PORT=')) dnsPort = t.substring(5).trim();
        if (t.startsWith('NAT=')) natOk = t.substring(4).trim() == '1';
        if (t.startsWith('SNI=')) sniOk = t.substring(4).trim() == '1';
      }
      return {
        'running': pid.isNotEmpty,
        'pid': pid,
        'dnsPort': dnsPort,
        'natOk': natOk,
        'sniOk': sniOk,
      };
    } catch (_) {
      return {
        'running': false,
        'pid': '',
        'dnsPort': '',
        'natOk': false,
        'sniOk': false,
      };
    }
  }

  Future<String> readModuleLogs({int maxLines = 150}) async {
    if (!_isAndroid) return '';
    try {
      final result = await Process.run(
        'su',
        ['-c', 'tail -n $maxLines /data/adb/agh/agh.log 2>/dev/null'],
      );
      if (result.exitCode != 0) return '';
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<bool> clearModuleLogs() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run(
        'su',
        ['-c', ': > /data/adb/agh/agh.log 2>/dev/null'],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reloadFirewallRules() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run(
        'su',
        [
          '-c',
          'pkill -f "/data/adb/agh/scripts/iptables.sh" 2>/dev/null; sh /data/adb/agh/scripts/iptables.sh >/dev/null 2>&1 &'
        ],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cleanAppAdCaches() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run(
        'su',
        [
          '-c',
          'rm -f /data/adb/agh/last_clean_time && rmdir /data/adb/agh/cache_clean.lock 2>/dev/null; sh /data/adb/agh/scripts/NoAdsService.sh >/dev/null 2>&1'
        ],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> readFactoryUserRules() async {
    if (!_isAndroid) return [];
    try {
      const cmd = '''
if [ -s /data/adb/agh/bin/default_user_rules.txt ]; then
  cat /data/adb/agh/bin/default_user_rules.txt
elif [ -s /data/adb/agh/backup/AdGuardHome.yaml ]; then
  awk '/^user_rules:/{f=1;next} f&&/^[a-zA-Z_]+:/{exit} f{print}' /data/adb/agh/backup/AdGuardHome.yaml | sed "s/^[[:space:]]*-[[:space:]]*//; s/^'//; s/'\$//; s/^\\"//; s/\\"\$//"
elif [ -s /data/adb/agh/bin/AdGuardHome.yaml ]; then
  awk '/^user_rules:/{f=1;next} f&&/^[a-zA-Z_]+:/{exit} f{print}' /data/adb/agh/bin/AdGuardHome.yaml | sed "s/^[[:space:]]*-[[:space:]]*//; s/^'//; s/'\$//; s/^\\"//; s/\\"\$//"
fi
''';
      final result = await Process.run('su', ['-c', cmd]);
      if (result.exitCode != 0) return [];
      return result.stdout
          .toString()
          .split('\n')
          .map((e) => e.trimRight())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> readAppAllowlist() async {
    if (!_isAndroid) return [];
    try {
      final result = await Process.run(
        'su',
        ['-c', '[ -f /data/adb/agh/app-allow.txt ] && cat /data/adb/agh/app-allow.txt || true'],
      );
      if (result.exitCode != 0) return [];
      return result.stdout
          .toString()
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && !e.startsWith('#'))
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveAppAllowlist(List<String> packages) async {
    if (!_isAndroid) return false;
    try {
      final content = packages.map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n');
      final escaped = content.replaceAll("'", "'\\''");
      final cmd = '''
mkdir -p /data/adb/agh
printf '%s\n' '$escaped' > /data/adb/agh/app-allow.txt
chmod 644 /data/adb/agh/app-allow.txt
''';
      final result = await Process.run('su', ['-c', cmd]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, String>>> getInstalledApps() async {
    if (!_isAndroid) return [];
    try {
      final result = await Process.run('su', ['-c', 'pm list packages -3 2>/dev/null || pm list packages 2>/dev/null']);
      if (result.exitCode != 0) return [];
      final lines = result.stdout.toString().split('\n');
      final List<Map<String, String>> apps = [];
      for (final raw in lines) {
        var pkg = raw.trim();
        if (pkg.startsWith('package:')) {
          pkg = pkg.substring('package:'.length).trim();
        }
        if (pkg.isNotEmpty) {
          apps.add({
            'package': pkg,
            'name': resolveKnownAppName(pkg),
          });
        }
      }
      apps.sort((a, b) => a['name']!.compareTo(b['name']!));
      return apps;
    } catch (_) {
      return [];
    }
  }

  static String resolveKnownAppName(String pkg) {
    const known = {
      'com.tencent.mm': '微信',
      'com.eg.android.AlipayGphone': '支付宝',
      'com.taobao.taobao': '手机淘宝',
      'com.jingdong.app.mall': '京东',
      'tv.danmaku.bili': '哔哩哔哩',
      'com.autonavi.minimap': '高德地图',
      'com.baidu.BaiduMap': '百度地图',
      'com.sankuai.meituan': '美团',
      'com.zhihu.android': '知乎',
      'com.xingin.xhs': '小红书',
      'com.ss.android.ugc.aweme': '抖音',
      'com.kuaishou.nebula': '快手',
      'com.netease.cloudmusic': '网易云音乐',
      'com.tencent.qqmusic': 'QQ音乐',
      'com.tencent.mobileqq': 'QQ',
      'com.sina.weibo': '微博',
      'com.alibaba.android.rimet': '钉钉',
      'com.tencent.wework': '企业微信',
      'com.unionpay': '云闪付',
      'com.tmall.wireless': '手机天猫',
      'com.xunmeng.pinduoduo': '拼多多',
      'com.dragon.read': '番茄免费小说',
      'com.coolapk.market': '酷安',
      'com.android.vending': 'Google Play 商店',
      'com.google.android.gms': 'Google Play 服务',
      'com.chinamworld.main': '中国建设银行',
      'com.icbc': '中国工商银行',
      'com.bankofchina.mpassport': '中国银行',
      'com.android.bankabc': '中国农业银行',
      'cmb.pb': '招商银行',
      'com.traffic.alipay.wz': '交管12123',
    };
    return known[pkg] ?? pkg;
  }
}

