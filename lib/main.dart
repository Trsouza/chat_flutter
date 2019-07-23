import 'package:chat_flutter/src/TelaPrincipal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
// DocumentSnapshot doc = await Firestore.instance.collection("usuarios").document("marcos").get();
// print(doc.data);

// Firestore.instance.collection("usuarios").snapshots().listen((snap){
//   for(DocumentSnapshot doc in snap.documents)
//     print(doc.data);
// });
  runApp(Myapp());
}

class Myapp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS
          ? iosTema
          : defaultTema,
      home: TelaPrincipal(),
    );
  }
}
