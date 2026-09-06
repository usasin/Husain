import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Fond PRONO4 optimisé : aucun blur animé permanent.
/// Beaucoup plus fluide sur anciens Android et iPad tout en gardant l'identité.
class WC2026Background extends StatelessWidget {
  final Widget child;
  final bool intense;
  const WC2026Background({super.key, required this.child, this.intense = false});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient))),
      Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
        gradient: RadialGradient(center: const Alignment(.65,-.75), radius: 1.15, colors: [AppColors.lime, Colors.transparent], stops: [0, .52], transform: _SoftTransform()),
      )))),
      const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _PitchPainter()))),
      child,
    ]);
  }
}

class _SoftTransform extends GradientTransform {
  const _SoftTransform();
  @override Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final m = Matrix4.diagonal3Values(1, .45, 1);
    m.setTranslationRaw(0, -bounds.height * .12, 0);
    return m;
  }
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter();
  @override void paint(Canvas canvas, Size size) {
    final p=Paint()..color=AppColors.lime.withOpacity(.035)..style=PaintingStyle.stroke..strokeWidth=1;
    final y=size.height*.73, x=size.width/2;
    canvas.drawLine(Offset(0,y),Offset(size.width,y),p); canvas.drawLine(Offset(x,y),Offset(x,size.height),p);
    canvas.drawOval(Rect.fromCenter(center:Offset(x,y+20),width:size.width*.62,height:76),p);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class WC2026Wordmark extends StatelessWidget {
  final double fontSize; const WC2026Wordmark({super.key,this.fontSize=14});
  @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[
    Text('P',style:GoogleFonts.spaceGrotesk(color:AppColors.text,fontSize:fontSize*1.55,fontWeight:FontWeight.w900,fontStyle:FontStyle.italic,letterSpacing:-2)),
    Text('4',style:GoogleFonts.spaceGrotesk(color:AppColors.lime,fontSize:fontSize*1.7,fontWeight:FontWeight.w900,fontStyle:FontStyle.italic,letterSpacing:-1)),
    const SizedBox(width:7), Text('PRONO',style:GoogleFonts.spaceGrotesk(color:AppColors.text,fontSize:fontSize,fontWeight:FontWeight.w900,letterSpacing:.4)),
    Text('4',style:GoogleFonts.spaceGrotesk(color:AppColors.lime,fontSize:fontSize,fontWeight:FontWeight.w900)),
  ]);
}
