import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sys_config_model.dart';
import '../models/tech_stats_model.dart';
import '../services/config_service.dart';

class ConfigProvider extends ChangeNotifier {
  static const _keyShowTechRank = 'pref_show_tech_rank';
  static const _keyShowAnnouncement = 'pref_show_announcement';

  final ConfigService _configService = ConfigService();

  List<SysConfigItem> _configs = [];
  bool _repairFlag = true;
  String _globalTips = '';
  String _submitTips = '';

  // 技术员榜单
  String _selectedCampusTab = '总榜';
  List<TopTechModel> _topTechList = [];
  bool _isLoadingRank = false;
  int _rankRequestId = 0; // 竞态防护：快速切换 Tab 时只接受最后一次请求的结果
  bool _showTechRank = true; // 首页是否展示技术员英雄榜
  bool _showAnnouncement = true; // 首页是否展示公告栏（仅技术员设置）

  ConfigProvider() {
    _loadLocalPreferences();
  }

  bool get repairFlag => _repairFlag;
  String get globalTips => _globalTips;
  String get submitTips => _submitTips;
  String get selectedCampusTab => _selectedCampusTab;
  List<TopTechModel> get topTechList => _topTechList;
  bool get isLoadingRank => _isLoadingRank;
  bool get showTechRank => _showTechRank;
  bool get showAnnouncement => _showAnnouncement;

  Future<void> _loadLocalPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRank = prefs.getBool(_keyShowTechRank);
      if (savedRank != null) {
        _showTechRank = savedRank;
      }
      final savedAnnounce = prefs.getBool(_keyShowAnnouncement);
      if (savedAnnounce != null) {
        _showAnnouncement = savedAnnounce;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setShowTechRank(bool value) async {
    if (_showTechRank == value) return;
    _showTechRank = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowTechRank, value);
    } catch (_) {}

    if (value && _topTechList.isEmpty) {
      await fetchTopTech();
    }
  }

  Future<void> setShowAnnouncement(bool value) async {
    if (_showAnnouncement == value) return;
    _showAnnouncement = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowAnnouncement, value);
    } catch (_) {}
  }

  Future<void> fetchConfig() async {
    try {
      _configs = await _configService.getConfig();
      for (final item in _configs) {
        if (item.name == 'Global_Flag') {
          _repairFlag = item.data == '1';
        } else if (item.name == 'Global_Tips') {
          _globalTips = item.data;
        } else if (item.name == 'Submit_Tips') {
          _submitTips = item.data;
        }
      }
      notifyListeners();
    } catch (_) {
      // 拉取失败时保留上一次配置（默认报修通道开启），避免开关状态与服务端相反
    }
  }

  Future<void> setCampusTab(String tab) async {
    _selectedCampusTab = tab;
    notifyListeners();
    await fetchTopTech();
  }

  Future<void> fetchTopTech() async {
    final requestId = ++_rankRequestId;
    _isLoadingRank = true;
    notifyListeners();
    try {
      final list = await _configService.getTopTech(campus: _selectedCampusTab);
      if (requestId != _rankRequestId) return; // 已有更新的请求，丢弃过期结果
      _topTechList = list;
    } catch (_) {
      if (requestId != _rankRequestId) return;
      _topTechList = [];
    }
    _isLoadingRank = false;
    notifyListeners();
  }
}
