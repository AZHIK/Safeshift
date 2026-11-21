/// Native Google Maps style applied while the surrounding Flutter theme is dark.
const safeShiftDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#202a35"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#bfccd8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#19222e"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#233b35"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#394958"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#293542"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#586478"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#314250"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#102b40"}]}
]
''';
