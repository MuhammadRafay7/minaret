// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter_qiblah/flutter_qiblah.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../../core/theme.dart';
// import '../../widgets/grain_overlay.dart';

// class QiblaPage extends StatefulWidget {
//   const QiblaPage({super.key});

//   @override
//   State<QiblaPage> createState() => _QiblaPageState();
// }

// class _QiblaPageState extends State<QiblaPage> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Stack(
//         children: [
//           const GrainOverlay(),
//           StreamBuilder(
//             stream: FlutterQiblah.qiblahStream,
//             builder: (context, AsyncSnapshot<QiblahDirection> snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(
//                   child: CircularProgressIndicator(
//                     color: Colors.black,
//                     strokeWidth: 0.8,
//                   ),
//                 );
//               }

//               if (snapshot.hasError || !snapshot.hasData) {
//                 return _sensorErrorState();
//               }

//               final qiblahDirection = snapshot.data!;

//               // MECHANICAL LOGIC:
//               // 1. dialTurns rotates the background based on where the phone is pointing relative to North.
//               double dialTurns = (qiblahDirection.direction * -1) / 360;

//               // 2. qiblaAngle is the fixed degree from North to Mecca (e.g., 261°).
//               double qiblaAngle = qiblahDirection.offset;

//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   // --- ATELIER LUXURY TOP MARGIN ---
//                   const SizedBox(height: 75),

//                   Text(
//                     "QIBLA ORIENTATION",
//                     style: MinaretTheme.detailHeader.copyWith(
//                       letterSpacing: 6,
//                       fontSize: 9,
//                       color: MinaretTheme.gold,
//                       fontWeight: FontWeight.w900,
//                     ),
//                   ),

//                   const Spacer(),

//                   // --- THE ACCURATE DIAL SYSTEM ---
//                   Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       // A. ROTATING BACKGROUND (The World)
//                       AnimatedRotation(
//                         turns: dialTurns,
//                         duration: const Duration(milliseconds: 250),
//                         curve: Curves.decelerate,
//                         child: Stack(
//                           alignment: Alignment.center,
//                           children: [
//                             // Outer Dial Circle
//                             Container(
//                               width: 310,
//                               height: 310,
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                   color: Colors.black.withOpacity(0.04),
//                                   width: 1.5,
//                                 ),
//                               ),
//                             ),

//                             // THE DYNAMIC KAABA ICON
//                             // This is placed at the specific Qibla degree on the dial
//                             Transform.rotate(
//                               angle: qiblaAngle * (math.pi / 180),
//                               child: Container(
//                                 height: 290,
//                                 alignment: Alignment.topCenter,
//                                 child: Column(
//                                   children: [
//                                     const Icon(
//                                       Icons.mosque,
//                                       color: MinaretTheme.gold,
//                                       size: 32,
//                                     ),
//                                     Text(
//                                       "KAABA",
//                                       style: GoogleFonts.montserrat(
//                                         fontSize: 8,
//                                         fontWeight: FontWeight.w900,
//                                         letterSpacing: 2,
//                                         color: MinaretTheme.gold,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),

//                             // Cardinal Markers (N, E, S, W)
//                             _buildCompassPoint("N", 0),
//                             _buildCompassPoint("E", 90),
//                             _buildCompassPoint("S", 180),
//                             _buildCompassPoint("W", 270),
//                           ],
//                         ),
//                       ),

//                       // B. FIXED INDICATOR (Your Phone's Direction)
//                       // Turn your phone until the Golden Mosque icon hits this line.
//                       Positioned(
//                         top: 0,
//                         child: Container(
//                           width: 3,
//                           height: 50,
//                           decoration: BoxDecoration(
//                             color: MinaretTheme.gold,
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                         ),
//                       ),

//                       // Center Pivot
//                       Container(
//                         width: 14,
//                         height: 14,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           shape: BoxShape.circle,
//                           border: Border.all(color: Colors.black, width: 2.5),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.1),
//                               blurRadius: 10,
//                             )
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),

//                   const Spacer(),

//                   // Numerical Readout Section
//                   Text(
//                     "${qiblaAngle.toStringAsFixed(0)}°",
//                     style: GoogleFonts.playfairDisplay(
//                       fontSize: 44,
//                       color: Colors.black,
//                       fontWeight: FontWeight.w600,
//                       fontStyle: FontStyle.italic,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     "MECCA RELATIVE TO NORTH",
//                     style: GoogleFonts.montserrat(
//                       fontSize: 7,
//                       letterSpacing: 3,
//                       color: Colors.black38,
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),

//                   const SizedBox(height: 140), // Space for the bottom dock
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCompassPoint(String label, double degree) {
//     return Transform.rotate(
//       angle: degree * (math.pi / 180),
//       child: Container(
//         height: 270,
//         alignment: Alignment.topCenter,
//         child: Text(
//           label,
//           style: GoogleFonts.inter(
//             fontSize: 11,
//             fontWeight: FontWeight.w900,
//             color: label == "N"
//                 ? Colors.red.withOpacity(0.5)
//                 : Colors.black.withOpacity(0.15),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _sensorErrorState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.sensors_off_outlined,
//             color: Colors.black.withOpacity(0.1),
//             size: 40,
//           ),
//           const SizedBox(height: 20),
//           Text(
//             "HARDWARE SENSOR NOT DETECTED",
//             style: GoogleFonts.montserrat(
//               color: Colors.black26,
//               fontSize: 8,
//               letterSpacing: 3,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
