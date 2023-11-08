import 'dart:math';
import 'package:charts_flutter/flutter.dart';
import 'package:charts_flutter/src/text_style.dart' as style;
import 'package:charts_flutter/src/text_element.dart' as element;
import 'package:flutter/material.dart';

typedef GetText = String Function();

class CustomCircleSymbolRenderer extends CircleSymbolRenderer {
  final GetText getText;
  final EdgeInsets padding;
  final double marginBottom;
  CustomCircleSymbolRenderer(this.getText, {this.marginBottom = 8, this.padding = const EdgeInsets.all(8)});
  @override
  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {List<int>? dashPattern, Color? fillColor, FillPatternType? fillPattern, Color? strokeColor, double? strokeWidthPx}) {
    super.paint(canvas, bounds, dashPattern: dashPattern, fillColor: fillColor, strokeColor: strokeColor, strokeWidthPx: strokeWidthPx);
    canvas.drawRect(Rectangle(bounds.left - 5, bounds.top - 30, bounds.width + 10, bounds.height + 10), fill: Color.white);
    var textStyle = style.TextStyle();
    textStyle.color = Color.black;
    textStyle.fontSize = 15;
    element.TextElement textElement = element.TextElement(getText.call(), style: textStyle);

    //canvas.drawText(textElement, (bounds.left).round(), (bounds.top - 28).round());

    double width = textElement.measurement.horizontalSliceWidth;
    double height = textElement.measurement.verticalSliceWidth;

    double centerX = bounds.left + bounds.width / 2;
    double centerY = bounds.top + bounds.height / 2 - marginBottom - (padding.top + padding.bottom);

    canvas.drawRRect(
      Rectangle(
        centerX - (width / 2) - padding.left,
        centerY - (height / 2) - padding.top,
        width + (padding.left + padding.right),
        height + (padding.top + padding.bottom),
      ),
      fill: Color.white,
      radius: 16,
      roundTopLeft: true,
      roundTopRight: true,
      roundBottomRight: true,
      roundBottomLeft: true,
    );
    canvas.drawText(
      textElement,
      (centerX - (width / 2)).round(),
      (centerY - (height / 2)).round(),
    );
  }
}
