import 'package:flutter/material.dart';

// ============================================================
// ANCHO DEL CONTENIDO
// ============================================================

// La app está pensada para un teléfono: listas a todo lo ancho y barra
// de navegación abajo. En la pantalla de una computadora eso queda
// desparramado —una fila de ranking de 1900 píxeles de ancho con el
// nombre a la izquierda y el récord perdido a la derecha—, así que el
// contenido se limita al ancho de un teléfono y se centra.
//
// En el teléfono no cambia absolutamente nada: la pantalla es más
// angosta que el límite, así que el contenido ocupa todo igual que
// siempre.
const double maxContentWidth = 600;

// Se aplica al `body` de cada Scaffold y no a la app entera a propósito.
// Envolviendo el MaterialApp también se encogerían la AppBar y la barra
// de navegación, y la app quedaría como un teléfono flotando en el medio
// de la ventana en vez de una página que ocupa el ancho completo.
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}

// Scaffold con el cuerpo ya centrado. Se usa en lugar de Scaffold en
// todas las pantallas para no repetir el envoltorio (y para no olvidarlo
// en una pantalla nueva).
//
// La AppBar, la barra de navegación y el botón flotante quedan a lo
// ancho completo a propósito: es lo que hace que se vea como una página
// y no como un teléfono flotando en el medio del monitor.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: CenteredContent(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
