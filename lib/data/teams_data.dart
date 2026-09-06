import '../models/models.dart';

const Map<String, TeamInfo> kTeams = {
  // Groupe A
  'MEX': TeamInfo(code:'MEX', name:'Mexique',         flagCode:'mx', group:'A', emoji:'🇲🇽'),
  'KOR': TeamInfo(code:'KOR', name:'Corée du Sud',    flagCode:'kr', group:'A', emoji:'🇰🇷'),
  'RSA': TeamInfo(code:'RSA', name:'Afrique du Sud',  flagCode:'za', group:'A', emoji:'🇿🇦'),
  'CZE': TeamInfo(code:'CZE', name:'Tchéquie',        flagCode:'cz', group:'A', emoji:'🇨🇿'),
  // Groupe B
  'CAN': TeamInfo(code:'CAN', name:'Canada',          flagCode:'ca', group:'B', emoji:'🇨🇦'),
  'SUI': TeamInfo(code:'SUI', name:'Suisse',          flagCode:'ch', group:'B', emoji:'🇨🇭'),
  'QAT': TeamInfo(code:'QAT', name:'Qatar',           flagCode:'qa', group:'B', emoji:'🇶🇦'),
  'BIH': TeamInfo(code:'BIH', name:'Bosnie-Herz.',    flagCode:'ba', group:'B', emoji:'🇧🇦'),
  // Groupe C
  'BRA': TeamInfo(code:'BRA', name:'Brésil',          flagCode:'br', group:'C', emoji:'🇧🇷'),
  'MAR': TeamInfo(code:'MAR', name:'Maroc',           flagCode:'ma', group:'C', emoji:'🇲🇦'),
  'SCO': TeamInfo(code:'SCO', name:'Écosse',          flagCode:'gb', group:'C', emoji:'🏴󠁧󠁢󠁳󠁣󠁴󠁿'),
  'HAI': TeamInfo(code:'HAI', name:'Haïti',           flagCode:'ht', group:'C', emoji:'🇭🇹'),
  // Groupe D
  'USA': TeamInfo(code:'USA', name:'États-Unis',      flagCode:'us', group:'D', emoji:'🇺🇸'),
  'AUS': TeamInfo(code:'AUS', name:'Australie',       flagCode:'au', group:'D', emoji:'🇦🇺'),
  'PAR': TeamInfo(code:'PAR', name:'Paraguay',        flagCode:'py', group:'D', emoji:'🇵🇾'),
  'TUR': TeamInfo(code:'TUR', name:'Turquie',         flagCode:'tr', group:'D', emoji:'🇹🇷'),
  // Groupe E
  'GER': TeamInfo(code:'GER', name:'Allemagne',       flagCode:'de', group:'E', emoji:'🇩🇪'),
  'ECU': TeamInfo(code:'ECU', name:'Équateur',        flagCode:'ec', group:'E', emoji:'🇪🇨'),
  'CIV': TeamInfo(code:'CIV', name:"Côte d'Ivoire",  flagCode:'ci', group:'E', emoji:'🇨🇮'),
  'CUR': TeamInfo(code:'CUR', name:'Curaçao',         flagCode:'cw', group:'E', emoji:'🇨🇼'),
  // Groupe F
  'NED': TeamInfo(code:'NED', name:'Pays-Bas',        flagCode:'nl', group:'F', emoji:'🇳🇱'),
  'JPN': TeamInfo(code:'JPN', name:'Japon',           flagCode:'jp', group:'F', emoji:'🇯🇵'),
  'TUN': TeamInfo(code:'TUN', name:'Tunisie',         flagCode:'tn', group:'F', emoji:'🇹🇳'),
  'SWE': TeamInfo(code:'SWE', name:'Suède',           flagCode:'se', group:'F', emoji:'🇸🇪'),
  // Groupe G
  'BEL': TeamInfo(code:'BEL', name:'Belgique',        flagCode:'be', group:'G', emoji:'🇧🇪'),
  'IRN': TeamInfo(code:'IRN', name:'Iran',            flagCode:'ir', group:'G', emoji:'🇮🇷'),
  'EGY': TeamInfo(code:'EGY', name:'Égypte',          flagCode:'eg', group:'G', emoji:'🇪🇬'),
  'NZL': TeamInfo(code:'NZL', name:'Nouvelle-Zélande',flagCode:'nz', group:'G', emoji:'🇳🇿'),
  // Groupe H
  'ESP': TeamInfo(code:'ESP', name:'Espagne',         flagCode:'es', group:'H', emoji:'🇪🇸'),
  'URU': TeamInfo(code:'URU', name:'Uruguay',         flagCode:'uy', group:'H', emoji:'🇺🇾'),
  'KSA': TeamInfo(code:'KSA', name:'Arabie Saoudite', flagCode:'sa', group:'H', emoji:'🇸🇦'),
  'CPV': TeamInfo(code:'CPV', name:'Cap-Vert',        flagCode:'cv', group:'H', emoji:'🇨🇻'),
  // Groupe I
  'FRA': TeamInfo(code:'FRA', name:'France',          flagCode:'fr', group:'I', emoji:'🇫🇷'),
  'SEN': TeamInfo(code:'SEN', name:'Sénégal',         flagCode:'sn', group:'I', emoji:'🇸🇳'),
  'NOR': TeamInfo(code:'NOR', name:'Norvège',         flagCode:'no', group:'I', emoji:'🇳🇴'),
  'IRQ': TeamInfo(code:'IRQ', name:'Irak',            flagCode:'iq', group:'I', emoji:'🇮🇶'),
  // Groupe J
  'ARG': TeamInfo(code:'ARG', name:'Argentine',       flagCode:'ar', group:'J', emoji:'🇦🇷'),
  'AUT': TeamInfo(code:'AUT', name:'Autriche',        flagCode:'at', group:'J', emoji:'🇦🇹'),
  'ALG': TeamInfo(code:'ALG', name:'Algérie',         flagCode:'dz', group:'J', emoji:'🇩🇿'),
  'JOR': TeamInfo(code:'JOR', name:'Jordanie',        flagCode:'jo', group:'J', emoji:'🇯🇴'),
  // Groupe K
  'POR': TeamInfo(code:'POR', name:'Portugal',        flagCode:'pt', group:'K', emoji:'🇵🇹'),
  'COL': TeamInfo(code:'COL', name:'Colombie',        flagCode:'co', group:'K', emoji:'🇨🇴'),
  'UZB': TeamInfo(code:'UZB', name:'Ouzbékistan',     flagCode:'uz', group:'K', emoji:'🇺🇿'),
  'COD': TeamInfo(code:'COD', name:'RD Congo',        flagCode:'cd', group:'K', emoji:'🇨🇩'),
  // Groupe L
  'ENG': TeamInfo(code:'ENG', name:'Angleterre',      flagCode:'gb', group:'L', emoji:'🏴󠁧󠁢󠁥󠁮󠁧󠁿'),
  'CRO': TeamInfo(code:'CRO', name:'Croatie',         flagCode:'hr', group:'L', emoji:'🇭🇷'),
  'PAN': TeamInfo(code:'PAN', name:'Panama',          flagCode:'pa', group:'L', emoji:'🇵🇦'),
  'GHA': TeamInfo(code:'GHA', name:'Ghana',           flagCode:'gh', group:'L', emoji:'🇬🇭'),
};

const List<String> kGroups = ['A','B','C','D','E','F','G','H','I','J','K','L'];
