import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class HutLoginSystem extends StatefulWidget {
  /// The initial idToken to pass to the CAS login URL
  final String initialIdToken;

  /// Callback function when token and cookie are successfully extracted
  final Function(Map<String, String>) onTokenAndCookieExtracted;

  /// Callback function when an error occurs during the login process
  final Function(String)? onError;

  const HutLoginSystem({
    Key? key,
    required this.initialIdToken,
    required this.onTokenAndCookieExtracted,
    this.onError,
  }) : super(key: key);

  @override
  State<HutLoginSystem> createState() => _HutLoginSystemState();
}

class _HutLoginSystemState extends State<HutLoginSystem> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  String _currentUrl = '';
  final String _targetDomain = 'jwxtsj.hut.edu.cn';
  final String _initialUrl = 'https://mycas.hut.edu.cn/cas/login';

  @override
  void initState() {
    super.initState();
  }

  // 检查URL并提取token和cookie
  void _checkUrlAndExtractTokenAndCookie(String url) async {
    _currentUrl = url;

    if (url.contains(_targetDomain) && url.contains('token=')) {
      try {
        // 解析URL获取token
        Uri uri = Uri.parse(url);
        String? token;

        // 如果URL包含片段(#)，需要特殊处理
        String fragment = uri.fragment;
        if (fragment.isNotEmpty && fragment.contains('token=')) {
          // 处理 #/casLogin?token=theNewToken&userType=2&toMenu=null 这种格式
          int tokenStartIndex =
              fragment.indexOf('token=') + 6; // 'token='.length
          int tokenEndIndex = fragment.indexOf('&', tokenStartIndex);

          if (tokenEndIndex == -1) {
            // 如果token是最后一个参数
            tokenEndIndex = fragment.length;
          }

          token = fragment.substring(tokenStartIndex, tokenEndIndex);
        } else {
          // 正常查询参数处理
          token = uri.queryParameters['token'];
        }

        if (token != null && token.isNotEmpty && _webViewController != null) {
          // 获取cookie
          String? myClientTicket = await _getCookie('my_client_ticket');
          
          // 创建结果Map
          Map<String, String> result = {
            'token': token,
            'my_client_ticket': myClientTicket ?? '',
          };
          
          widget.onTokenAndCookieExtracted(result);
        }
      } catch (e) {
        if (widget.onError != null) {
          widget.onError!('Token和Cookie提取错误: $e');
        }
      }
    }
  }

  // 获取指定名称的cookie
  Future<String?> _getCookie(String cookieName) async {
    if (_webViewController == null) return null;
    
    try {
      CookieManager cookieManager = CookieManager.instance();
      List<Cookie> cookies = await cookieManager.getCookies(
        url: WebUri(_currentUrl),
      );
      
      for (Cookie cookie in cookies) {
        if (cookie.name == cookieName) {
          return cookie.value;
        }
      }
      
      // 如果在当前域名没找到，尝试从其他相关域名获取
      List<String> relatedDomains = [
        'https://mycas.hut.edu.cn',
        'https://jwxtsj.hut.edu.cn',
      ];
      
      for (String domain in relatedDomains) {
        try {
          List<Cookie> domainCookies = await cookieManager.getCookies(
            url: WebUri(domain),
          );
          for (Cookie cookie in domainCookies) {
            if (cookie.name == cookieName) {
              return cookie.value;
            }
          }
        } catch (e) {
          // 忽略单个域名的错误，继续尝试下一个
          print('获取域名 $domain 的cookie时出错: $e');
        }
      }
      
      return null;
    } catch (e) {
      print('获取cookie时出错: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUT统一认证'),
        leading: SizedBox(),
        //  leading: IconButton(
        //    icon: const Icon(Icons.arrow_back),
        //    onPressed: () => Navigator.of(context).pop(),
        //  ),
        //  actions: [
        //    if (_webViewController != null)
        //      IconButton(
        //        icon: const Icon(Icons.refresh),
        //        onPressed: () => _webViewController!.reload(),
        //      ),
        //  ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(
                '$_initialUrl?idToken=${widget.initialIdToken}&service=https%3A%2F%2Fjwxtsj.hut.edu.cn%2Fnjwhd%2FloginSso&token=${widget.initialIdToken}',
              ),
              headers: {
                "User-Agent":
                    "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
                "Connection": "keep-alive",
                "Accept":
                    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                "Accept-Encoding": "gzip, deflate, br, zstd",
                "sec-ch-ua":
                    "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
                "sec-ch-ua-mobile": "?1",
                "sec-ch-ua-platform": "\"Android\"",
                "upgrade-insecure-requests": "1",
                "x-requested-with": "com.supwisdom.hut",
                "sec-fetch-site": "none",
                "sec-fetch-mode": "navigate",
                "sec-fetch-user": "?1",
                "sec-fetch-dest": "document",
                "accept-language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
              },
            ),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                useShouldOverrideUrlLoading: true,
                useOnLoadResource: true,
                javaScriptEnabled: true,
                cacheEnabled: true,
              ),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();
              _checkUrlAndExtractTokenAndCookie(url);
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, url) {
              if (url != null) {
                setState(() {
                  _isLoading = true;
                  _currentUrl = url.toString();
                });
                _checkUrlAndExtractTokenAndCookie(_currentUrl);
              }
            },
            onLoadStop: (controller, url) {
              if (url != null) {
                setState(() {
                  _isLoading = false;
                  _currentUrl = url.toString();
                });
                _checkUrlAndExtractTokenAndCookie(_currentUrl);

                // 输出当前URL到控制台，便于调试
                print('页面加载完成: $_currentUrl');
              }
            },
            onLoadError: (controller, url, code, message) {
              setState(() {
                _isLoading = false;
              });
              if (widget.onError != null) {
                widget.onError!('页面加载错误: $message');
              }
            },
            onConsoleMessage: (controller, consoleMessage) {
              print('Console: ${consoleMessage.message}');
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// 使用示例：

class HutLoginExample extends StatelessWidget {
  final String idToken;

  const HutLoginExample({Key? key, required this.idToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HutLoginSystem(
      initialIdToken: idToken,
      onTokenAndCookieExtracted: (result) {
        // 处理提取到的token和cookie
        String token = result['token'] ?? '';
        String myClientTicket = result['my_client_ticket'] ?? '';
        print('提取到的token: $token');
        print('提取到的my_client_ticket: $myClientTicket');
        // 这里可以保存token和cookie或导航到其他页面
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登录成功！')));
        Navigator.of(context).pop(result); // 返回包含token和cookie的Map并关闭页面
      },
      onError: (errorMessage) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        // );
      },
    );
  }
}
