import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PaperRepository {
  Future<String?> load();
  Future<void> save(String snapshot);
}

class LocalPaperRepository implements PaperRepository {
  static const key = 'tipkhun.paper.synthetic.v1';
  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> save(String snapshot) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      key,
      snapshot,
    )) {
      throw StateError('Paper save failed');
    }
  }
}
