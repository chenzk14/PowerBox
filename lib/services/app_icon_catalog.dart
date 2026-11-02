import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:simple_icons/simple_icons.dart';

/// 图标来源：Material 通用图标 / Simple Icons 品牌图标 / Font Awesome 品牌图标
enum AppIconKind { material, simple, fontAwesome }

/// 一个可选的本地图标。
class AppIconOption {
  final String key;
  final String label;
  final IconData icon;
  final AppIconKind kind;
  final Color? color;
  final List<String> keywords;

  const AppIconOption({
    required this.key,
    required this.label,
    required this.icon,
    this.kind = AppIconKind.simple,
    this.color,
    this.keywords = const [],
  });
}

/// 图标分组，用于图标选择器展示。
class AppIconCategory {
  final String name;
  final List<AppIconOption> icons;

  const AppIconCategory({required this.name, required this.icons});
}

// 便于书写图标数据的简写方法
AppIconOption _s(
  String key,
  String label,
  IconData icon,
  Color? color, [
  List<String> keywords = const [],
]) {
  return AppIconOption(
    key: key,
    label: label,
    icon: icon,
    kind: AppIconKind.simple,
    color: color,
    keywords: keywords,
  );
}

AppIconOption _m(
  String key,
  String label,
  IconData icon, [
  List<String> keywords = const [],
]) {
  return AppIconOption(
    key: key,
    label: label,
    icon: icon,
    kind: AppIconKind.material,
    keywords: keywords,
  );
}

AppIconOption _fa(
  String key,
  String label,
  IconData icon,
  Color color, [
  List<String> keywords = const [],
]) {
  return AppIconOption(
    key: key,
    label: label,
    icon: icon,
    kind: AppIconKind.fontAwesome,
    color: color,
    keywords: keywords,
  );
}

/// 本地预置图标库。
/// 不依赖网络，添加密码时既可按名称自动匹配，也可手动选择。
final List<AppIconCategory> appIconCategories = [
  AppIconCategory(
    name: '常用应用',
    icons: [
      _s('wechat', '微信', SimpleIcons.wechat, SimpleIconColors.wechat,
          ['微信', 'wechat', 'weixin', 'weixin.qq.com']),
      _s('qq', 'QQ', SimpleIcons.qq, SimpleIconColors.qq,
          ['qq', 'qq.com', 'qq邮箱']),
      _s('alipay', '支付宝', SimpleIcons.alipay, SimpleIconColors.alipay,
          ['支付宝', 'alipay', 'alipay.com']),
      _s('taobao', '淘宝', SimpleIcons.taobao, SimpleIconColors.taobao,
          ['淘宝', 'taobao', 'taobao.com']),
      _m('tmall', '天猫', Icons.shopping_bag_outlined, ['天猫', 'tmall', 'tmall.com']),
      _m('jd', '京东', Icons.shopping_cart_outlined,
          ['京东', 'jd', 'jd.com', 'jingdong']),
      _m('pinduoduo', '拼多多', Icons.local_mall_outlined,
          ['拼多多', 'pinduoduo', 'pinduoduo.com']),
      _s('douyin', '抖音', SimpleIcons.tiktok, SimpleIconColors.tiktok,
          ['抖音', 'douyin', 'tiktok']),
      _s('bilibili', '哔哩哔哩', SimpleIcons.bilibili, SimpleIconColors.bilibili,
          ['哔哩哔哩', 'b站', 'bilibili', 'bilibili.com']),
      _s('weibo', '微博', SimpleIcons.sinaweibo, SimpleIconColors.sinaweibo,
          ['微博', 'weibo', 'sinaweibo', 'weibo.com']),
      _s('zhihu', '知乎', SimpleIcons.zhihu, SimpleIconColors.zhihu,
          ['知乎', 'zhihu', 'zhihu.com']),
      _s('xiaohongshu', '小红书', SimpleIcons.xiaohongshu,
          SimpleIconColors.xiaohongshu,
          ['小红书', 'xiaohongshu', 'xhs']),
      _s('baidu', '百度', SimpleIcons.baidu, SimpleIconColors.baidu,
          ['百度', 'baidu', 'baidu.com']),
      _s('meituan', '美团', SimpleIcons.meituan, SimpleIconColors.meituan,
          ['美团', 'meituan', 'meituan.com']),
      _s('kuaishou', '快手', SimpleIcons.kuaishou, SimpleIconColors.kuaishou,
          ['快手', 'kuaishou']),
      _s('netease', '网易云音乐', SimpleIcons.neteasecloudmusic,
          SimpleIconColors.neteasecloudmusic,
          ['网易', '网易云音乐', 'netease', 'music.163.com']),
      _s('douban', '豆瓣', SimpleIcons.douban, SimpleIconColors.douban,
          ['豆瓣', 'douban', 'douban.com']),
      _s('xiaomi', '小米', SimpleIcons.xiaomi, SimpleIconColors.xiaomi,
          ['小米', 'xiaomi', 'mi.com']),
      _s('huawei', '华为', SimpleIcons.huawei, SimpleIconColors.huawei,
          ['华为', 'huawei']),
      _s('aliyun', '阿里云', SimpleIcons.alibabacloud,
          SimpleIconColors.alibabacloud, ['阿里云', 'aliyun', 'alibabacloud']),
      _m('tencent', '腾讯', Icons.cloud_outlined, ['腾讯', 'tencent']),
      _m('ctrip', '携程', Icons.flight_takeoff, ['携程', 'ctrip', 'trip.com']),
      _m('didi', '滴滴', Icons.local_taxi_outlined, ['滴滴', 'didi']),
      _m('gaode', '高德地图', Icons.map_outlined, ['高德', 'gaode', 'amap']),
      _m('wps', 'WPS', Icons.description_outlined, ['wps', '金山']),
      _m('dingtalk', '钉钉', Icons.chat_outlined, ['钉钉', 'dingtalk']),
      _m('feishu', '飞书', Icons.forum_outlined, ['飞书', 'feishu', 'lark']),
      _m('toutiao', '今日头条', Icons.newspaper_outlined, ['头条', 'toutiao']),
    ],
  ),
  AppIconCategory(
    name: '社交沟通',
    icons: [
      _s('facebook', 'Facebook', SimpleIcons.facebook,
          SimpleIconColors.facebook, ['facebook', '脸书']),
      _s('instagram', 'Instagram', SimpleIcons.instagram,
          SimpleIconColors.instagram, ['instagram', 'ins']),
      _s('x', 'X', SimpleIcons.x, SimpleIconColors.x,
          ['x.com', 'twitter', '推特']),
      _s('telegram', 'Telegram', SimpleIcons.telegram,
          SimpleIconColors.telegram, ['telegram', '电报']),
      _s('whatsapp', 'WhatsApp', SimpleIcons.whatsapp,
          SimpleIconColors.whatsapp, ['whatsapp']),
      _s('discord', 'Discord', SimpleIcons.discord, SimpleIconColors.discord,
          ['discord']),
      _fa('slack', 'Slack', FontAwesomeIcons.slack.data, const Color(0xFF4A154B),
          ['slack']),
      _s('line', 'LINE', SimpleIcons.line, SimpleIconColors.line, ['line']),
      _fa('skype', 'Skype', FontAwesomeIcons.skype.data, const Color(0xFF00AFF0),
          ['skype']),
      _fa('linkedin', 'LinkedIn', FontAwesomeIcons.linkedin.data,
          const Color(0xFF0A66C2), ['linkedin', '领英']),
      _s('messenger', 'Messenger', SimpleIcons.messenger,
          SimpleIconColors.messenger, ['messenger']),
      _s('viber', 'Viber', SimpleIcons.viber, SimpleIconColors.viber, ['viber']),
      _s('snapchat', 'Snapchat', SimpleIcons.snapchat,
          SimpleIconColors.snapchat, ['snapchat']),
      _s('reddit', 'Reddit', SimpleIcons.reddit, SimpleIconColors.reddit,
          ['reddit']),
      _s('pinterest', 'Pinterest', SimpleIcons.pinterest,
          SimpleIconColors.pinterest, ['pinterest']),
      _s('tumblr', 'Tumblr', SimpleIcons.tumblr, SimpleIconColors.tumblr,
          ['tumblr']),
      _s('vk', 'VK', SimpleIcons.vk, SimpleIconColors.vk, ['vk']),
      _s('quora', 'Quora', SimpleIcons.quora, SimpleIconColors.quora,
          ['quora']),
      _s('medium', 'Medium', SimpleIcons.medium, SimpleIconColors.medium,
          ['medium']),
      _s('signal', 'Signal', SimpleIcons.signal, SimpleIconColors.signal,
          ['signal']),
    ],
  ),
  AppIconCategory(
    name: '支付金融',
    icons: [
      _s('paypal', 'PayPal', SimpleIcons.paypal, SimpleIconColors.paypal,
          ['paypal', '贝宝']),
      _s('stripe', 'Stripe', SimpleIcons.stripe, SimpleIconColors.stripe,
          ['stripe']),
      _s('visa', 'Visa', SimpleIcons.visa, SimpleIconColors.visa, ['visa']),
      _s('mastercard', 'Mastercard', SimpleIcons.mastercard,
          SimpleIconColors.mastercard, ['mastercard', '万事达']),
      _s('applepay', 'Apple Pay', SimpleIcons.applepay,
          SimpleIconColors.applepay, ['apple pay', 'applepay']),
      _s('googlepay', 'Google Pay', SimpleIcons.googlepay,
          SimpleIconColors.googlepay, ['google pay', 'googlepay']),
      _m('bank', '银行', Icons.account_balance,
          ['银行', 'bank', '招商银行', '工商银行', '建设银行', '农业银行', '中国银行', '交通银行']),
      _m('wallet', '钱包', Icons.account_balance_wallet_outlined, ['钱包', 'wallet']),
      _m('creditcard', '信用卡', Icons.credit_card, ['信用卡', 'credit card']),
      _s('bitcoin', 'Bitcoin', SimpleIcons.bitcoin, SimpleIconColors.bitcoin,
          ['bitcoin', '比特币']),
      _s('ethereum', 'Ethereum', SimpleIcons.ethereum,
          SimpleIconColors.ethereum, ['ethereum', '以太坊']),
      _s('binance', 'Binance', SimpleIcons.binance, SimpleIconColors.binance,
          ['binance', '币安']),
      _s('coinbase', 'Coinbase', SimpleIcons.coinbase,
          SimpleIconColors.coinbase, ['coinbase']),
      _s('revolut', 'Revolut', SimpleIcons.revolut, SimpleIconColors.revolut,
          ['revolut']),
      _s('wise', 'Wise', SimpleIcons.wise, SimpleIconColors.wise, ['wise']),
      _s('square', 'Square', SimpleIcons.square, SimpleIconColors.square,
          ['square']),
      _m('stock', '股票', Icons.trending_up, ['股票', 'stock', '证券']),
      _m('insurance', '保险', Icons.shield_outlined, ['保险', 'insurance']),
      _m('loan', '贷款', Icons.request_quote_outlined, ['贷款', 'loan', '借款']),
      _m('invoice', '账单', Icons.receipt_long_outlined,
          ['账单', 'invoice', '发票']),
    ],
  ),
  AppIconCategory(
    name: '购物生活',
    icons: [
      _fa('amazon', 'Amazon', FontAwesomeIcons.amazon.data,
          const Color(0xFFFF9900), ['amazon', '亚马逊']),
      _s('ebay', 'eBay', SimpleIcons.ebay, SimpleIconColors.ebay, ['ebay']),
      _s('aliexpress', 'AliExpress', SimpleIcons.aliexpress,
          SimpleIconColors.aliexpress, ['aliexpress', '速卖通']),
      _s('shopify', 'Shopify', SimpleIcons.shopify, SimpleIconColors.shopify,
          ['shopify']),
      _s('etsy', 'Etsy', SimpleIcons.etsy, SimpleIconColors.etsy, ['etsy']),
      _s('target', 'Target', SimpleIcons.target, SimpleIconColors.target,
          ['target']),
      _m('walmart', 'Walmart', Icons.storefront_outlined, ['walmart', '沃尔玛']),
      _m('costco', 'Costco', Icons.store_outlined, ['costco', '开市客']),
      _s('ikea', 'IKEA', SimpleIcons.ikea, SimpleIconColors.ikea,
          ['ikea', '宜家']),
      _s('nike', 'Nike', SimpleIcons.nike, SimpleIconColors.nike, ['nike']),
      _s('adidas', 'Adidas', SimpleIcons.adidas, SimpleIconColors.adidas,
          ['adidas', '阿迪达斯']),
      _s('starbucks', 'Starbucks', SimpleIcons.starbucks,
          SimpleIconColors.starbucks, ['starbucks', '星巴克']),
      _s('mcdonalds', "McDonald's", SimpleIcons.mcdonalds,
          SimpleIconColors.mcdonalds, ['mcdonalds', '麦当劳']),
      _s('uber', 'Uber', SimpleIcons.uber, SimpleIconColors.uber, ['uber']),
      _s('lyft', 'Lyft', SimpleIcons.lyft, SimpleIconColors.lyft, ['lyft']),
      _s('doordash', 'DoorDash', SimpleIcons.doordash,
          SimpleIconColors.doordash, ['doordash']),
      _s('airbnb', 'Airbnb', SimpleIcons.airbnb, SimpleIconColors.airbnb,
          ['airbnb', '爱彼迎']),
      _s('booking', 'Booking', SimpleIcons.bookingdotcom,
          SimpleIconColors.bookingdotcom, ['booking']),
      _s('expedia', 'Expedia', SimpleIcons.expedia, SimpleIconColors.expedia,
          ['expedia']),
      _s('trip', 'Trip.com', SimpleIcons.tripdotcom,
          SimpleIconColors.tripdotcom, ['trip.com', '携程旅行']),
      _s('shopee', 'Shopee', SimpleIcons.shopee, SimpleIconColors.shopee,
          ['shopee', '虾皮']),
      _s('rakuten', 'Rakuten', SimpleIcons.rakuten, SimpleIconColors.rakuten,
          ['rakuten', '乐天']),
      _m('food', '外卖', Icons.delivery_dining,
          ['外卖', '饿了么', '美团外卖', 'delivery']),
      _m('restaurant', '餐厅', Icons.restaurant, ['餐厅', '饭店', 'restaurant']),
      _m('coffee', '咖啡', Icons.local_cafe_outlined, ['咖啡', 'coffee']),
      _m('gift', '礼物', Icons.card_giftcard, ['礼物', 'gift']),
      _m('coupon', '优惠券', Icons.local_offer_outlined, ['优惠券', 'coupon']),
      _m('cart', '购物', Icons.shopping_cart_outlined,
          ['购物', 'shopping', '商城']),
    ],
  ),
  AppIconCategory(
    name: '影音娱乐',
    icons: [
      _s('youtube', 'YouTube', SimpleIcons.youtube, SimpleIconColors.youtube,
          ['youtube', '油管']),
      _s('netflix', 'Netflix', SimpleIcons.netflix, SimpleIconColors.netflix,
          ['netflix', '奈飞']),
      _s('spotify', 'Spotify', SimpleIcons.spotify, SimpleIconColors.spotify,
          ['spotify']),
      _s('soundcloud', 'SoundCloud', SimpleIcons.soundcloud,
          SimpleIconColors.soundcloud, ['soundcloud']),
      _s('twitch', 'Twitch', SimpleIcons.twitch, SimpleIconColors.twitch,
          ['twitch']),
      _s('vimeo', 'Vimeo', SimpleIcons.vimeo, SimpleIconColors.vimeo,
          ['vimeo']),
      _s('dailymotion', 'Dailymotion', SimpleIcons.dailymotion,
          SimpleIconColors.dailymotion, ['dailymotion']),
      _s('steam', 'Steam', SimpleIcons.steam, SimpleIconColors.steam,
          ['steam', '蒸汽平台']),
      _s('playstation', 'PlayStation', SimpleIcons.playstation,
          SimpleIconColors.playstation, ['playstation', 'psn', '索尼']),
      _fa('xbox', 'Xbox', FontAwesomeIcons.xbox.data, const Color(0xFF107C10),
          ['xbox', '微软游戏']),
      _m('nintendo', 'Nintendo', Icons.sports_esports,
          ['nintendo', '任天堂', 'switch']),
      _s('epicgames', 'Epic Games', SimpleIcons.epicgames, null,
          ['epic', 'epicgames']),
      _m('movie', '电影', Icons.movie_outlined, ['电影', 'movie', '影院']),
      _m('music', '音乐', Icons.music_note_outlined, ['音乐', 'music']),
      _m('video', '视频', Icons.play_circle_outline, ['视频', 'video']),
      _m('podcast', '播客', Icons.podcasts, ['播客', 'podcast']),
      _m('radio', '电台', Icons.radio, ['电台', 'radio']),
      _m('tv', '电视', Icons.tv, ['电视', 'tv']),
      _m('game', '游戏', Icons.sports_esports, ['游戏', 'game']),
    ],
  ),
  AppIconCategory(
    name: '开发工具',
    icons: [
      _s('github', 'GitHub', SimpleIcons.github, SimpleIconColors.github,
          ['github', 'github.com']),
      _s('gitlab', 'GitLab', SimpleIcons.gitlab, SimpleIconColors.gitlab,
          ['gitlab']),
      _s('bitbucket', 'Bitbucket', SimpleIcons.bitbucket,
          SimpleIconColors.bitbucket, ['bitbucket']),
      _s('stackoverflow', 'Stack Overflow', SimpleIcons.stackoverflow,
          SimpleIconColors.stackoverflow, ['stackoverflow', 'stack overflow']),
      _s('npm', 'npm', SimpleIcons.npm, SimpleIconColors.npm, ['npm']),
      _s('yarn', 'Yarn', SimpleIcons.yarn, SimpleIconColors.yarn, ['yarn']),
      _s('docker', 'Docker', SimpleIcons.docker, SimpleIconColors.docker,
          ['docker']),
      _m('kubernetes', 'Kubernetes', Icons.dns_outlined,
          ['kubernetes', 'k8s']),
      _fa('aws', 'AWS', FontAwesomeIcons.aws.data, const Color(0xFFFF9900),
          ['aws', 'amazon web services', '亚马逊云']),
      _s('gcp', 'Google Cloud', SimpleIcons.googlecloud,
          SimpleIconColors.googlecloud, ['google cloud', 'gcp', '谷歌云']),
      _m('azure', 'Azure', Icons.cloud_outlined, ['azure', '微软云']),
      _s('cloudflare', 'Cloudflare', SimpleIcons.cloudflare,
          SimpleIconColors.cloudflare, ['cloudflare']),
      _s('vercel', 'Vercel', SimpleIcons.vercel, SimpleIconColors.vercel,
          ['vercel']),
      _s('netlify', 'Netlify', SimpleIcons.netlify, SimpleIconColors.netlify,
          ['netlify']),
      _s('firebase', 'Firebase', SimpleIcons.firebase,
          SimpleIconColors.firebase, ['firebase']),
      _s('supabase', 'Supabase', SimpleIcons.supabase,
          SimpleIconColors.supabase, ['supabase']),
      _s('mongodb', 'MongoDB', SimpleIcons.mongodb, SimpleIconColors.mongodb,
          ['mongodb']),
      _s('mysql', 'MySQL', SimpleIcons.mysql, SimpleIconColors.mysql,
          ['mysql']),
      _s('postgresql', 'PostgreSQL', SimpleIcons.postgresql,
          SimpleIconColors.postgresql, ['postgresql', 'postgres']),
      _s('redis', 'Redis', SimpleIcons.redis, SimpleIconColors.redis,
          ['redis']),
      _s('elasticsearch', 'Elasticsearch', SimpleIcons.elasticsearch,
          SimpleIconColors.elasticsearch, ['elasticsearch', 'elastic']),
      _s('grafana', 'Grafana', SimpleIcons.grafana, SimpleIconColors.grafana,
          ['grafana']),
      _s('jenkins', 'Jenkins', SimpleIcons.jenkins, SimpleIconColors.jenkins,
          ['jenkins']),
      _s('jira', 'Jira', SimpleIcons.jira, SimpleIconColors.jira, ['jira']),
      _s('confluence', 'Confluence', SimpleIcons.confluence,
          SimpleIconColors.confluence, ['confluence']),
      _s('trello', 'Trello', SimpleIcons.trello, SimpleIconColors.trello,
          ['trello']),
      _s('asana', 'Asana', SimpleIcons.asana, SimpleIconColors.asana,
          ['asana']),
      _s('notion', 'Notion', SimpleIcons.notion, SimpleIconColors.notion,
          ['notion']),
      _s('figma', 'Figma', SimpleIcons.figma, SimpleIconColors.figma,
          ['figma']),
      _m('adobe', 'Adobe', Icons.brush_outlined, ['adobe', 'ps', 'pr']),
      _s('blender', 'Blender', SimpleIcons.blender, SimpleIconColors.blender,
          ['blender']),
      _s('unity', 'Unity', SimpleIcons.unity, SimpleIconColors.unity,
          ['unity']),
      _s('python', 'Python', SimpleIcons.python, SimpleIconColors.python,
          ['python']),
      _s('java', 'Java', SimpleIcons.openjdk, SimpleIconColors.openjdk,
          ['java', 'jdk']),
      _s('node', 'Node.js', SimpleIcons.nodedotjs, SimpleIconColors.nodedotjs,
          ['node', 'nodejs', 'node.js']),
      _s('react', 'React', SimpleIcons.react, SimpleIconColors.react,
          ['react']),
      _s('vue', 'Vue.js', SimpleIcons.vuedotjs, SimpleIconColors.vuedotjs,
          ['vue', 'vuejs']),
      _s('angular', 'Angular', SimpleIcons.angular, SimpleIconColors.angular,
          ['angular']),
      _s('php', 'PHP', SimpleIcons.php, SimpleIconColors.php, ['php']),
      _s('wordpress', 'WordPress', SimpleIcons.wordpress,
          SimpleIconColors.wordpress, ['wordpress', 'wp']),
      _fa('codepen', 'CodePen', FontAwesomeIcons.codepen.data,
          const Color(0xFF000000), ['codepen']),
      _s('leetcode', 'LeetCode', SimpleIcons.leetcode,
          SimpleIconColors.leetcode, ['leetcode', '力扣']),
      _s('hackerrank', 'HackerRank', SimpleIcons.hackerrank,
          SimpleIconColors.hackerrank, ['hackerrank']),
      _s('kaggle', 'Kaggle', SimpleIcons.kaggle, SimpleIconColors.kaggle,
          ['kaggle']),
      _s('digitalocean', 'DigitalOcean', SimpleIcons.digitalocean,
          SimpleIconColors.digitalocean, ['digitalocean']),
      _m('heroku', 'Heroku', Icons.cloud_upload_outlined, ['heroku']),
      _s('maven', 'Maven', SimpleIcons.apachemaven,
          SimpleIconColors.apachemaven, ['maven']),
      _s('gradle', 'Gradle', SimpleIcons.gradle, SimpleIconColors.gradle,
          ['gradle']),
      _m('code', '代码', Icons.code, ['代码', 'code', '编程']),
      _m('terminal', '终端', Icons.terminal, ['终端', 'terminal', 'ssh']),
      _m('bug', '缺陷', Icons.bug_report_outlined, ['bug', '缺陷']),
      _m('api', 'API', Icons.api, ['api', '接口']),
      _m('database', '数据库', Icons.storage, ['数据库', 'database', 'sql']),
      _m('server', '服务器', Icons.dns, ['服务器', 'server', 'vps']),
      _m('domain', '域名', Icons.language, ['域名', 'domain']),
      _m('hosting', '主机', Icons.cloud_queue, ['主机', 'hosting']),
    ],
  ),
  AppIconCategory(
    name: '系统工具',
    icons: [
      _s('google', 'Google', SimpleIcons.google, SimpleIconColors.google,
          ['google', '谷歌']),
      _fa('microsoft', 'Microsoft', FontAwesomeIcons.microsoft.data,
          const Color(0xFF5E5E5E), ['microsoft', '微软']),
      _s('apple', 'Apple', SimpleIcons.apple, SimpleIconColors.apple,
          ['apple', '苹果', 'apple id', 'icloud']),
      _fa('windows', 'Windows', FontAwesomeIcons.windows.data,
          const Color(0xFF0078D4), ['windows', '微软系统']),
      _s('android', 'Android', SimpleIcons.android, SimpleIconColors.android,
          ['android', '安卓']),
      _s('linux', 'Linux', SimpleIcons.linux, SimpleIconColors.linux, ['linux']),
      _s('ubuntu', 'Ubuntu', SimpleIcons.ubuntu, SimpleIconColors.ubuntu,
          ['ubuntu']),
      _s('chrome', 'Chrome', SimpleIcons.googlechrome,
          SimpleIconColors.googlechrome, ['chrome', '谷歌浏览器']),
      _s('firefox', 'Firefox', SimpleIcons.firefox, SimpleIconColors.firefox,
          ['firefox', '火狐']),
      _fa('edge', 'Edge', FontAwesomeIcons.edge.data, const Color(0xFF0078D7),
          ['edge', '微软浏览器']),
      _s('safari', 'Safari', SimpleIcons.safari, SimpleIconColors.safari,
          ['safari']),
      _s('opera', 'Opera', SimpleIcons.opera, SimpleIconColors.opera,
          ['opera']),
      _s('brave', 'Brave', SimpleIcons.brave, SimpleIconColors.brave,
          ['brave']),
      _s('duckduckgo', 'DuckDuckGo', SimpleIcons.duckduckgo,
          SimpleIconColors.duckduckgo, ['duckduckgo']),
      _s('gmail', 'Gmail', SimpleIcons.gmail, SimpleIconColors.gmail,
          ['gmail', '谷歌邮箱']),
      _m('outlook', 'Outlook', Icons.mail_outline, ['outlook', 'hotmail']),
      _s('icloud', 'iCloud', SimpleIcons.icloud, SimpleIconColors.icloud,
          ['icloud']),
      _s('dropbox', 'Dropbox', SimpleIcons.dropbox, SimpleIconColors.dropbox,
          ['dropbox']),
      _s('googledrive', 'Google Drive', SimpleIcons.googledrive,
          SimpleIconColors.googledrive, ['google drive', '谷歌云盘']),
      _m('onedrive', 'OneDrive', Icons.cloud_outlined, ['onedrive', '微软云盘']),
      _s('protonmail', 'ProtonMail', SimpleIcons.protonmail,
          SimpleIconColors.protonmail, ['protonmail', 'proton']),
      _s('evernote', 'Evernote', SimpleIcons.evernote,
          SimpleIconColors.evernote, ['evernote', '印象笔记']),
      _s('zoom', 'Zoom', SimpleIcons.zoom, SimpleIconColors.zoom, ['zoom']),
      _s('googlemeet', 'Google Meet', SimpleIcons.googlemeet,
          SimpleIconColors.googlemeet, ['google meet', '谷歌会议']),
      _s('webex', 'Webex', SimpleIcons.webex, SimpleIconColors.webex,
          ['webex']),
      _m('teams', 'Microsoft Teams', Icons.groups_outlined,
          ['teams', '微软teams']),
      _m('vpn', 'VPN', Icons.vpn_key_outlined, ['vpn', '加速器']),
      _s('nordvpn', 'NordVPN', SimpleIcons.nordvpn,
          SimpleIconColors.nordvpn, ['nordvpn']),
      _s('expressvpn', 'ExpressVPN', SimpleIcons.expressvpn,
          SimpleIconColors.expressvpn, ['expressvpn']),
      _s('surfshark', 'Surfshark', SimpleIcons.surfshark,
          SimpleIconColors.surfshark, ['surfshark']),
      _s('bitwarden', 'Bitwarden', SimpleIcons.bitwarden,
          SimpleIconColors.bitwarden, ['bitwarden']),
      _s('lastpass', 'LastPass', SimpleIcons.lastpass,
          SimpleIconColors.lastpass, ['lastpass']),
      _s('dashlane', 'Dashlane', SimpleIcons.dashlane,
          SimpleIconColors.dashlane, ['dashlane']),
      _s('1password', '1Password', SimpleIcons.n1password,
          SimpleIconColors.n1password, ['1password']),
      _m('password', '密码', Icons.password, ['密码', 'password']),
      _m('key', '密钥', Icons.key, ['密钥', 'key']),
      _m('lock', '锁', Icons.lock_outline, ['锁', 'lock']),
      _m('shield', '安全', Icons.shield_outlined, ['安全', 'security']),
      _m('identity', '身份', Icons.badge_outlined, ['身份', '身份证', 'id']),
      _m('email', '邮箱', Icons.email_outlined, ['邮箱', 'email', 'mail']),
      _m('sms', '短信', Icons.sms_outlined, ['短信', 'sms']),
      _m('phone', '电话', Icons.phone_outlined, ['电话', 'phone']),
      _m('contacts', '通讯录', Icons.contacts_outlined, ['通讯录', 'contacts']),
      _m('calendar', '日历', Icons.calendar_month_outlined,
          ['日历', 'calendar']),
      _m('todo', '待办', Icons.checklist, ['待办', 'todo']),
      _m('note', '笔记', Icons.note_outlined, ['笔记', 'note']),
      _m('docs', '文档', Icons.description_outlined, ['文档', 'docs']),
      _m('spreadsheet', '表格', Icons.table_chart_outlined,
          ['表格', 'excel', 'spreadsheet']),
      _m('presentation', '演示', Icons.slideshow_outlined,
          ['演示', 'ppt', 'presentation']),
      _m('cloud', '云盘', Icons.cloud_outlined, ['云盘', 'cloud']),
      _m('backup', '备份', Icons.backup_outlined, ['备份', 'backup']),
      _m('wifi', 'WiFi', Icons.wifi, ['wifi', '无线']),
      _m('router', '路由器', Icons.router_outlined, ['路由器', 'router']),
      _m('printer', '打印机', Icons.print_outlined, ['打印机', 'printer']),
      _m('computer', '电脑', Icons.computer, ['电脑', 'computer', 'pc']),
      _m('tablet', '平板', Icons.tablet_mac, ['平板', 'tablet']),
      _m('watch', '手表', Icons.watch_outlined, ['手表', 'watch']),
      _m('camera', '相机', Icons.camera_alt_outlined, ['相机', 'camera']),
      _m('photo', '相册', Icons.photo_library_outlined, ['相册', 'photo']),
    ],
  ),
  AppIconCategory(
    name: '通用场景',
    icons: [
      _m('map', '地图', Icons.map_outlined, ['地图', 'map']),
      _m('flight', '机票', Icons.flight, ['机票', '航班', 'flight']),
      _m('train', '火车', Icons.train_outlined, ['火车', '高铁', 'train']),
      _m('bus', '公交', Icons.directions_bus_outlined, ['公交', 'bus']),
      _m('car', '汽车', Icons.directions_car_outlined, ['汽车', 'car']),
      _m('hotel', '酒店', Icons.hotel_outlined, ['酒店', 'hotel']),
      _m('home', '家庭', Icons.home_outlined, ['家庭', 'home']),
      _m('school', '学校', Icons.school_outlined, ['学校', '教育', 'school']),
      _m('work', '工作', Icons.work_outline, ['工作', 'work', '公司']),
      _m('fitness', '健身', Icons.fitness_center, ['健身', 'fitness', 'gym']),
      _m('medical', '医疗', Icons.local_hospital_outlined,
          ['医疗', '医院', 'medical']),
      _m('pet', '宠物', Icons.pets, ['宠物', 'pet']),
      _m('baby', '母婴', Icons.child_friendly_outlined, ['母婴', 'baby']),
      _m('gamepad', '手柄', Icons.sports_esports, ['手柄', 'gamepad']),
      _m('star', '收藏', Icons.star_outline, ['收藏', 'star']),
      _m('bookmark', '书签', Icons.bookmark_outline, ['书签', 'bookmark']),
      _m('book', '图书', Icons.menu_book_outlined, ['图书', 'book']),
      _m('news', '新闻', Icons.newspaper_outlined, ['新闻', 'news']),
      _m('forum', '论坛', Icons.forum_outlined, ['论坛', 'forum']),
      _m('blog', '博客', Icons.rss_feed, ['博客', 'blog', 'rss']),
      _m('ai', 'AI', Icons.smart_toy_outlined, ['ai', '人工智能']),
      _m('chatbot', '聊天机器人', Icons.support_agent, ['机器人', 'chatbot']),
      _m('analytics', '分析', Icons.analytics_outlined, ['分析', 'analytics']),
      _m('monitor', '监控', Icons.monitor_heart_outlined, ['监控', 'monitor']),
      _m('translate', '翻译', Icons.translate, ['翻译', 'translate']),
      _m('calculator', '计算器', Icons.calculate_outlined,
          ['计算器', 'calculator']),
      _m('clock', '时钟', Icons.access_time, ['时钟', 'clock']),
      _m('weather', '天气', Icons.wb_sunny_outlined, ['天气', 'weather']),
      _m('giftcard', '礼品卡', Icons.card_giftcard, ['礼品卡', 'giftcard']),
    ],
  ),
];

/// 去重后的全部图标（同一 key 只保留第一次出现的项）。
final List<AppIconOption> allAppIcons = _buildAllIcons();

List<AppIconOption> _buildAllIcons() {
  final map = <String, AppIconOption>{};
  for (final category in appIconCategories) {
    for (final option in category.icons) {
      map.putIfAbsent(option.key, () => option);
    }
  }
  return map.values.toList();
}

/// 按 key 查找图标。
AppIconOption? findAppIconByKey(String key) {
  for (final option in allAppIcons) {
    if (option.key == key) return option;
  }
  return null;
}

/// 根据名称自动匹配图标，匹配不到返回 null（回退到首字母头像）。
AppIconOption? matchAppIcon(String text) {
  final normalized = text.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  AppIconOption? best;
  int bestScore = 0;

  for (final option in allAppIcons) {
    for (final keyword in option.keywords) {
      final k = keyword.toLowerCase();
      if (k.isEmpty) continue;
      // 名称包含关键词，或关键词包含名称（名称至少两个字符，避免单字误匹配）
      final matched = normalized.contains(k) ||
          (normalized.length >= 2 && k.contains(normalized));
      if (!matched) continue;
      // 关键词越长越精确，优先选择更具体的图标
      if (k.length > bestScore) {
        bestScore = k.length;
        best = option;
      }
    }
  }
  return best;
}

/// 图标选择器中的搜索。
List<AppIconOption> searchAppIcons(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return allAppIcons.where((option) {
    return option.label.toLowerCase().contains(q) ||
        option.key.toLowerCase().contains(q) ||
        option.keywords.any((k) => k.toLowerCase().contains(q));
  }).toList();
}

/// 统一的图标渲染方法，兼容 Material / Simple Icons / Font Awesome。
Widget buildAppIcon(AppIconOption option, {double? size, Color? color}) {
  final iconColor = color ?? option.color ?? const Color(0xFF333333);
  if (option.kind == AppIconKind.fontAwesome) {
    return FaIcon(FaIconData(option.icon), size: size, color: iconColor);
  }
  return Icon(option.icon, size: size, color: iconColor);
}
