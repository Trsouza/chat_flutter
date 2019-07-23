import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

final ThemeData iosTema = ThemeData(
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light,
  primarySwatch: Colors.orange,
);

final ThemeData defaultTema = ThemeData(
  primaryColor: Colors.purple,
  primarySwatch: Colors.orange,
);

//await auth.signInWithCredential(GoogleAuthProvider.getCredential(idToken: credentials.idToken, accessToken: credentials.accessToken));
final _googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

//GoogleSignIn googleSignIn = GoogleSignIn(
//  scopes: <String>[
//    'email',
//    'https://www.googleapis.com/auth/contacts.readonly',
//  ],
//);

Future<Null> _garanteLogin() async {
  // tanto no google, quanto no firebase
  GoogleSignInAccount usuario = _googleSignIn.currentUser;
  if (usuario == null)
    usuario = await _googleSignIn
        .signInSilently(); // tenta logar silenciosamente, pois o usuário pode já ter efetuado login antes
  if (usuario == null) usuario = await _googleSignIn.signIn();
  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credenciais =
    await _googleSignIn.currentUser.authentication;
    await auth.signInWithCredential(GoogleAuthProvider.getCredential(
        idToken: credenciais.idToken, accessToken: credenciais.accessToken));
  }
}

void _submiterTexto(String texto) async {
  // Pega o texto e envia para o banco de dados
  await _garanteLogin();
  _messagem(texto: texto);
}

void _messagem({String texto, String imgUrl}) {
  Firestore.instance.collection("mensagens").add({
    "texto": texto,
    "imgUrl": imgUrl,
    "emissorNome": _googleSignIn.currentUser.displayName,
    "emissorFotoUrl": _googleSignIn.currentUser.photoUrl
  });
}


class TelaPrincipal extends StatefulWidget {
  @override
  _TelaPrincipalState createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  Map<String, dynamic> _ultimoRemovido;
  int _ultimoRemovidoPsicao;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Chat"),
//          centerTitle: true,
          elevation:
          Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(

                  stream:
                  Firestore.instance.collection("mensagens").snapshots(),
                  builder: (context, snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      default:
                        return ListView.builder(

                            reverse: true,
                            itemCount: snapshot.data.documents.length,
                            itemBuilder: (context, index) {
                              List reversa =
                              snapshot.data.documents.reversed.toList();
                              return Dismissible(
                                //É necessario uma key, para identificar qual item da lista  dverá ser excluído, e deverá ser diferente para cada item
                                // key, vai receber o tempo atual em milissegundos, poderia ser um randon
                                key: Key(DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString()),
                                background: Container(
                                  color: Colors.green,
                                  child: Align(
                                    alignment: Alignment(-0.9, 0.0),
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                direction: DismissDirection.startToEnd,
                                onDismissed: (direcao) async {
//                                  print(reversa[index]["texto"]);
                                  await Firestore.instance.runTransaction(
                                          (Transaction myTransaction) async {
                                        await myTransaction.delete(reversa[index].reference);
                                      });
                                },

                                child: ChatMessage(reversa[index].data),
                              );
                            });
                    }
                  }),
            ),
            Divider(
              height: 10.0,
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: TextoComposer(),
            )
          ],
        ),
      ),
    );
  }
}

class TextoComposer extends StatefulWidget {
  @override
  _TextoComposerState createState() => _TextoComposerState();
}

class _TextoComposerState extends State<TextoComposer> {
  void _reset() {
    _textoController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  final _textoController = TextEditingController();
  bool _isComposing = false;

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[200])))
            : null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                icon: Icon(Icons.photo_camera),
                onPressed: () async {
                  await _garanteLogin();
                  File imgFile =
                  await ImagePicker.pickImage(source: ImageSource.camera);
                  if (imgFile == null) return;
                  StorageUploadTask task = FirebaseStorage.instance
                      .ref()
                      .child(_googleSignIn.currentUser.toString() +
                      DateTime.now().millisecondsSinceEpoch.toString())
                      .putFile(imgFile);
                  StorageTaskSnapshot taskSnapshot = await task.onComplete;
                  String url = await taskSnapshot.ref.getDownloadURL();
                  _messagem(imgUrl: url);

//                    StorageUploadTask task = FirebaseStorage.instance.ref().
//                    child(googleSignIn.currentUser.id.toString() +
//                        DateTime.now().millisecondsSinceEpoch.toString()).putFile(imgFile);
//                    _enviarMessagem(imgUrl: (await task.future).downloadUrl.toString());
                },
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textoController,
                decoration:
                InputDecoration.collapsed(hintText: "Enviar uma mensagem"),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: (texto) {
                  // chamando essa função aqui eu consigo enviar aa msg pelo botão de enviar do teclado
                  _submiterTexto(texto);
                  _reset();
                },
              ),
            ),
            Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton(
                  child: Text("Enviar"),
                  onPressed: _isComposing
                      ? () {
                    _submiterTexto(_textoController.text);
                    _reset();
                  }
                      : null, // o null serve para eu nao estiver compando ele desabilita o botao
                )
                    : IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isComposing
                      ? () {
                    _submiterTexto(_textoController.text);
                    _reset();
                  }
                      : null,
                )),
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget { // Cards das mensagens
  final Map<String, dynamic> data;

  ChatMessage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(

      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(data["emissorFotoUrl"]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data["emissorNome"],
                  style: Theme.of(context).textTheme.subhead,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: data["imgUrl"] != null
                      ? Image.network(
                    data["imgUrl"],
                    width: 250.0,
                  )
                      : Text(data["texto"]),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
