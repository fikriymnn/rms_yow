import 'package:flutter/widgets.dart';

enum FormFactor { phone, tablet, desktop }

const kTabletMin = 600.0;
const kDesktopMin = 1024.0;

FormFactor formFactorOf(double width) => width >= kDesktopMin
    ? FormFactor.desktop
    : width >= kTabletMin
    ? FormFactor.tablet
    : FormFactor.phone;

extension FormFactorContext on BuildContext {
  /// Berdasarkan lebar jendela. Di dalam halaman, untuk kolom kisi lebih baik pakai LayoutBuilder.
  FormFactor get formFactor => formFactorOf(MediaQuery.sizeOf(this).width);
}

/// Jumlah kolom kisi yang muat untuk lebar tertentu.
int gridColumns(double width, {double minTile = 180}) {
  final n = (width / minTile).floor();
  return n < 1 ? 1 : n;
}
