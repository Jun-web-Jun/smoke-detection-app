// 플랫폼별 조건부 export
// 웹에서는 live_screen_simple_web.dart를, 모바일에서는 live_screen_simple_mobile.dart를 사용
export 'live_screen_simple_mobile.dart'
    if (dart.library.html) 'live_screen_simple_web.dart';
