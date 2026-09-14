class ApiConstants {
  static const String rootApiUrl = 'https://focapi.feiyang.ac.cn';
  static const String defaultTicketImage =
      'https://focapp.feiyang.ac.cn/public/ticketdefault.svg';
  // 客服/激活电话（服务端 config.php activephone，2026-09-11 核实）
  static const String supportPhone = '19150105675';

  // Auth & User（路径已于 2026-09-11 逐一对照服务器 PHP 文件名核实，注意大小写）
  static const String userLogin = '/v1/user/login';
  // 小程序注册/验证端点（App 不可直接调用：需 wx.login 会话 token）；
  // 2026-09-14 服务端补丁：verify 支持 App 注册账号（app_ openid）合并绑定微信 openid
  static const String userRegister = '/v1/user/register';
  static const String userVerify = '/v1/user/verify';
  static const String userMigration = '/v1/user/migration';
  static const String getUserInfo = '/v1/user/getUserInfo';
  // 服务端实际路由为 /v1/user/setuser（setUserInfo.php 不存在），字段白名单见服务端 setuser.php；
  // 技术员意愿（wants/canDuo）同样走 setuser，服务端无独立 setTechInfo 路由
  static const String setUserInfo = '/v1/user/setuser';
  // App 端短信登录（2026-09-10 新增，服务端 phonesend.php / phonelogin.php）
  static const String phoneSend = '/v1/user/phonesend';
  static const String phoneLogin = '/v1/user/phonelogin';
  // App/网页端手机号注册（2026-09-14 新增，服务端 phoneregsend.php / phoneregister.php）
  static const String phoneRegSend = '/v1/user/phoneregsend';
  static const String phoneRegister = '/v1/user/phoneregister';
  static const String userDelete = '/v1/user/delete';
  static const String newPhone = '/v1/user/newphone';
  static const String phoneVerify = '/v1/user/phonechange_verify';
  static const String newEmail = '/v1/user/newemail';
  static const String userAvatar = '/v1/user/avatar';

  // Tickets
  static const String getTicket = '/v1/status/getTicket';
  static const String addTicket = '/v1/ticket/create';
  static const String giveTicket = '/v1/ticket/give';
  static const String completeTicket = '/v1/ticket/complete';
  static const String setTicketStatus = '/v1/ticket/set';
  static const String setCompleteImage = '/v1/ticket/set';
  static const String ticketStatusCheck = '/v1/status/getTicketStatus';

  // Config & Stats
  static const String getConfig = '/v1/conf/get';
  static const String setConfig = '/v1/conf/set';
  static const String getTopTech = '/v1/status/getLaomo';
  // 服务端文件为 v1/status/getTechSum.php（不在 user/ 下）
  static const String getTechSum = '/v1/status/getTechSum';
  static const String feedbackAdd = '/v1/feedback/add';

  // Events（服务端文件位于 v1/event/ 下）
  static const String getEvent = '/v1/status/getEvent';
  static const String regEvent = '/v1/event/regevent';
  static const String regRepair = '/v1/event/regrepair';
  // 服务端真实路由为 /v1/status/getLuckynum（getLuckynum.php），参数 activity_id + user_id
  static const String getLuckyNum = '/v1/status/getLuckynum';

  // 应用更新检测（GitHub Releases 侧载分发，匿名调用限额 60 次/时/IP，检查频率足够）
  static const String githubApiBase = 'https://api.github.com';
  static const String githubRepo = 'gkxqh/foc_app';

  // Options
  static const List<String> campuses = ['江安', '望江', '华西'];
  static const List<String> deviceTypes = [
    '笔记本 (Laptop)',
    'MacBook (Mac)',
    '台式机 (PC)',
    '其他设备 (Others)',
  ];
  static const List<String> brands = [
    '戴尔 DELL',
    '华为 HUAWEI',
    '联想 Lenovo',
    '华硕 ASUS',
    '苹果 Apple',
    '神舟 HASEE',
    '三星 SamSung',
    '微软 MicroSoft',
    '惠普 HP',
    '宏碁 Acer',
    '雷蛇 Razer',
    'ThinkPad',
    '外星人 Alienware',
    '雷神 Thunder',
    '机械师 MACHENIKE',
    '微星 Msi',
    '其他',
  ];
  static const List<String> problemTypes = [
    '设备清灰',
    '系统重装',
    '无法开机',
    '设备进水',
    '软件问题',
    '硬件加(改)装',
  ];
  static const List<String> contactTypes = [
    'QQ号',
    '微信号',
    'WhatsApp',
    'Telegram',
    'Messenger',
  ];
}
