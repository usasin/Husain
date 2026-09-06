import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/competitions_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/match_card.dart';
import '../widgets/wc26_background.dart';
import '../providers/app_provider.dart';
import '../services/ad_service.dart';
import '../l10n/app_locale.dart';

class MatchDetailScreen extends StatelessWidget {
  final FootballMatch match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final comp = competitionById(match.competitionId);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WC2026Background(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.text, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comp == null ? context.tr('Match','Match') : competitionDisplayName(context, comp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            (match.stage ?? '').isEmpty
                                ? context.tr('Pronostic','Prediction')
                                : match.stage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppColors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.lime.withOpacity(.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'PRONO4',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.lime,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                  children: [
                    Text(
                      context.tr('Mon pronostic','My prediction'),
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MatchCard(match: match),
                    const SizedBox(height: 12),
                    _ExactScorePicker(match: match),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('Le foot se pronostique en équipe.','Football predictions are better as a team.'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ExactScorePicker extends StatefulWidget {
  final FootballMatch match;
  const _ExactScorePicker({required this.match});
  @override State<_ExactScorePicker> createState()=>_ExactScorePickerState();
}

class _ExactScorePickerState extends State<_ExactScorePicker> {
  int home=1, away=1; bool initialized=false, busy=false;
  @override Widget build(BuildContext context) {
    final prov=context.watch<AppProvider>();
    final saved=prov.getExactPrediction(widget.match.id);
    if(!initialized){ initialized=true; if(saved!=null){home=saved.homeScore; away=saved.awayScore;} }
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color:AppColors.bg2.withOpacity(.95),borderRadius:BorderRadius.circular(18),border:Border.all(color:AppColors.lime.withOpacity(.14))),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:Text(context.tr('Score exact','Exact score'),style:GoogleFonts.spaceGrotesk(color:AppColors.text,fontSize:17,fontWeight:FontWeight.w900))),
          Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:AppColors.lime.withOpacity(.10),borderRadius:BorderRadius.circular(99)),child:Text(context.tr('+2 pts bonus','+2 bonus pts'),style:GoogleFonts.inter(color:AppColors.lime,fontSize:9,fontWeight:FontWeight.w900))),
        ]),
        const SizedBox(height:5),
        Text(context.tr('Le résultat correct vaut 3 pts. Le score exact ajoute 2 pts.','Correct result earns 3 pts. Exact score adds 2 pts.'),style:GoogleFonts.inter(color:AppColors.text2,fontSize:10.5)),
        const SizedBox(height:14),
        Row(children:[
          Expanded(child:_scoreSide(widget.match.homeName ?? widget.match.homeCode,home,(v)=>setState(()=>home=v))),
          Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:Text('-',style:GoogleFonts.spaceGrotesk(color:AppColors.grey,fontSize:24,fontWeight:FontWeight.w900))),
          Expanded(child:_scoreSide(widget.match.awayName ?? widget.match.awayCode,away,(v)=>setState(()=>away=v))),
        ]),
        const SizedBox(height:14),
        SizedBox(width:double.infinity,child:FilledButton.icon(
          onPressed:busy?null:() async {
            setState(()=>busy=true);
            final err=await prov.castExactScore(widget.match.id,home,away);
            if(mounted)setState(()=>busy=false);
            if(!context.mounted)return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(err??context.tr('Score exact enregistré 🎯','Exact score saved 🎯'))));
            if(err==null) AdService.instance.maybeShowPredictionInterstitial();
          },
          icon:busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.check_rounded),
          label:Text(context.tr('VALIDER LE SCORE EXACT','SAVE EXACT SCORE')),
        )),
      ]),
    );
  }
  Widget _scoreSide(String name,int value,ValueChanged<int> onChanged)=>Column(children:[
    Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:GoogleFonts.inter(color:AppColors.text2,fontSize:10,fontWeight:FontWeight.w700)),
    const SizedBox(height:7),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      _round(Icons.remove_rounded,()=>onChanged((value-1).clamp(0,20).toInt())),
      SizedBox(width:36,child:Text('$value',textAlign:TextAlign.center,style:GoogleFonts.spaceGrotesk(color:AppColors.text,fontSize:24,fontWeight:FontWeight.w900))),
      _round(Icons.add_rounded,()=>onChanged((value+1).clamp(0,20).toInt())),
    ]),
  ]);
  Widget _round(IconData icon,VoidCallback tap)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(99),child:Container(width:30,height:30,decoration:BoxDecoration(color:AppColors.bg3,shape:BoxShape.circle,border:Border.all(color:Colors.white.withOpacity(.08))),child:Icon(icon,size:16,color:AppColors.lime)));
}
